defmodule Partners.Services.Paypal do
  @moduledoc """
  Service module for all PayPal API interactions.

  This module encapsulates the logic for communicating with the PayPal API for various
  operations, including but not limited to:

  - **OAuth Token Management**:
    - `get_access_token/0`: Retrieves an OAuth2 access token from PayPal, which is
      required for authenticating subsequent API calls. It handles the request and
      response processing.

  - **Subscription Creation**:
    - `create_subscription/2`: Creates a new PayPal subscription for a given user and
      plan ID. It builds the necessary payload, including return and cancel URLs,
      and `custom_id` for associating the subscription with the local user.
    - `extract_approval_url/1`: Extracts the `approve` link from the subscription
      creation response, which is used to redirect the user to PayPal for approval.

  - **Subscription Details Retrieval**:
    - `get_subscription_details/1`: Fetches the details of an existing PayPal
      subscription by its ID. This function is notably used by the
      `PaypalWebhookController` as a fallback mechanism when webhook signature
      verification fails. If the controller cannot verify a webhook, it calls this
      function to directly query PayPal about the subscription's status.

  - **Webhook Event Processing**:
    - `process_webhook_event/3`: Takes a PayPal event type (e.g.,
      "BILLING.SUBSCRIPTION.ACTIVATED") and the webhook resource data to determine
      the corresponding internal subscription state (e.g., `:active`, `:cancelled`).
      This mapped state is then used by the `PaypalWebhookController` to broadcast
      updates.

  - **Configuration Management**:
    - Provides helper functions (`api_url/0`, `client_id/0`, `client_secret/0`,
      `return_url/0`, `cancel_url/0`, `webhook_id/0`, `plan_id/0`) to access
      PayPal-related application configuration (e.g., API base URL, credentials,
      webhook ID, default plan ID) stored in `config/paypal.exs` or environment
      variables. These functions raise an error if essential configuration is missing.

  All API interactions are performed using the `Req` HTTP client library. Logging is
  implemented to trace requests, responses, and errors during PayPal API communication.
  """

  require Logger

  # Private configuration access functions

  def api_url do
    Application.fetch_env!(:partners, __MODULE__)[:base_url] ||
      "https://api-m.sandbox.paypal.com"
  end

  def client_id do
    case Application.get_env(:partners, __MODULE__)[:client_id] do
      nil -> raise "PayPal client ID not configured"
      id -> id
    end
  end

  def client_secret do
    case Application.get_env(:partners, __MODULE__)[:secret] do
      nil -> raise "PayPal client secret not configured"
      secret -> secret
    end
  end

  def return_url do
    case Application.fetch_env!(:partners, __MODULE__)[:return_url] do
      nil -> raise "PayPal return URL not configured"
      url -> url
    end
  end

  def cancel_url do
    case Application.fetch_env!(:partners, __MODULE__)[:cancel_url] do
      nil -> raise "PayPal cancel URL not configured"
      url -> url
    end
  end

  def webhook_id do
    case Application.fetch_env!(:partners, __MODULE__)[:webhook_id] do
      nil -> raise "PayPal webhook ID not configured"
      id -> id
    end
  end

  def plan_id do
    case Application.fetch_env!(:partners, __MODULE__)[:plan_id] do
      nil -> raise "PayPal plan ID not configured"
      id -> id
    end
  end

  @doc """
  Builds the authorization header for PayPal API requests.
  """
  def auth_header do
    auth = Base.encode64("#{client_id()}:#{client_secret()}")
    {"Authorization", "Basic #{auth}"}
  end

  @doc """
  Makes a request to the PayPal OAuth endpoint to obtain an access token.
  """
  def request_access_token do
    Req.post("#{api_url()}/v1/oauth2/token",
      headers: [
        auth_header(),
        {"Content-Type", "application/x-www-form-urlencoded"}
      ],
      form: [grant_type: "client_credentials"]
    )
  end

  @doc """
  Processes the response from the access token request.
  """
  def process_token_response({:ok, %{status: 200, body: %{"access_token" => token}}}) do
    {:ok, token}
  end

  def process_token_response({:ok, %{status: status, body: body}}) do
    Logger.error("Failed to get PayPal access token. Status: #{status}, Body: #{inspect(body)}")
    {:error, body}
  end

  def process_token_response({:error, error}) do
    Logger.error("Error requesting PayPal access token: #{inspect(error)}")
    {:error, error}
  end

  @doc """
  Gets an OAuth access token from PayPal.

  Returns:
    * `{:ok, token}` - The token was successfully retrieved
    * `{:error, reason}` - An error occurred while retrieving the token
  """
  def get_access_token do
    request_access_token() |> process_token_response()
  end

  @doc """
  Builds the subscription payload for creating a new subscription.
  """
  def build_subscription_payload(user_id, plan_id_to_use) do
    %{
      plan_id: plan_id_to_use,
      application_context: %{
        brand_name: "Loving Partners",
        locale: "en-US",
        shipping_preference: "NO_SHIPPING",
        user_action: "SUBSCRIBE_NOW",
        return_url: return_url(),
        cancel_url: cancel_url()
      },
      custom_id: user_id,
      subscriber: %{
        subscription_custom_id: "user_#{user_id}"
      }
    }
  end

  @doc """
  Makes a request to create a subscription with the PayPal API.
  """
  def request_create_subscription(token, payload) do
    Req.post("#{api_url()}/v1/billing/subscriptions",
      headers: [
        {"Authorization", "Bearer #{token}"},
        {"Content-Type", "application/json"}
      ],
      json: payload
    )
  end

  @doc """
  Processes the response from the create subscription request.
  """
  def process_subscription_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Logger.info("Successfully created PayPal subscription: #{inspect(body)}")
    {:ok, body}
  end

  def process_subscription_response({:ok, %{status: status, body: body}}) do
    Logger.error(
      "Failed to create PayPal subscription. Status: #{status}, Body: #{inspect(body)}"
    )

    {:error, body}
  end

  def process_subscription_response({:error, error}) do
    Logger.error("Error creating PayPal subscription: #{inspect(error)}")
    {:error, error}
  end

  @doc """
  Creates a PayPal subscription for a user.

  Args:
    * `user_id` - The ID of the user creating the subscription
    * `plan_id_to_use` - The specific PayPal plan ID to subscribe the user to

  Returns:
    * `{:ok, subscription_data}` - The subscription was successfully created
    * `{:error, reason}` - An error occurred while creating the subscription
  """
  def create_subscription(user_id, plan_id_to_use) do
    with {:ok, token} <- get_access_token(),
         payload <- build_subscription_payload(user_id, plan_id_to_use),
         response <- request_create_subscription(token, payload) do
      process_subscription_response(response)
    end
  end

  @doc """
  Gets details for a specific PayPal subscription.

  Args:
    * `paypal_subscription_id` - The ID of the PayPal subscription to retrieve.

  Returns:
    * `{:ok, subscription_data}` - The subscription details were successfully retrieved.
    * `{:error, reason}` - An error occurred while retrieving the subscription details.
  """
  def get_subscription_details(paypal_subscription_id) do
    # --- ORIGINAL CODE (Reverted after testing Scenario 3) ---
    with {:ok, token} <- get_access_token(),
         response <- request_get_subscription_details(token, paypal_subscription_id) do
      process_get_subscription_details_response(response)
    end
  end

  defp request_get_subscription_details(token, paypal_subscription_id) do
    url = "#{api_url()}/v1/billing/subscriptions/#{paypal_subscription_id}"

    Logger.info(
      "Requesting PayPal subscription details for ID: #{paypal_subscription_id} from URL: #{url}"
    )

    Req.get(url,
      headers: [
        {"Authorization", "Bearer #{token}"},
        {"Content-Type", "application/json"}
      ]
    )
  end

  defp process_get_subscription_details_response({:ok, %{status: status, body: body}})
       when status in 200..299 do
    Logger.info("Successfully retrieved PayPal subscription details: #{inspect(body)}")
    {:ok, body}
  end

  defp process_get_subscription_details_response({:ok, %{status: status, body: body}}) do
    Logger.error(
      "Failed to retrieve PayPal subscription details. Status: #{status}, Body: #{inspect(body)}"
    )

    {:error, body}
  end

  defp process_get_subscription_details_response({:error, error}) do
    Logger.error("Error retrieving PayPal subscription details: #{inspect(error)}")
    {:error, error}
  end

  @doc """
  Extracts a specific link from a PayPal API response.
  """
def extract_link(subscription_data, rel) do
  links = subscription_data["links"] || []

  case Enum.find(links, fn link -> link["rel"] == rel end) do
    %{"href" => url} -> {:ok, url}
    nil -> {:error, :link_not_found}
    _ -> {:error, :invalid_link_format}
  end
end

  @doc """
  Extracts the approval URL from a PayPal subscription response.
  """
  def extract_approval_url(subscription_data) do
    extract_link(subscription_data, "approve")
  end

  @doc """
  Maps a PayPal event type to our internal subscription state.
  """
  def map_event_to_state(event_type) do
    case event_type do
      "BILLING.SUBSCRIPTION.CREATED" -> :pending
      "BILLING.SUBSCRIPTION.ACTIVATED" -> :active
      "BILLING.SUBSCRIPTION.CANCELLED" -> :cancelled
      "PAYMENT.SALE.COMPLETED" -> :active
      "PAYMENT.SALE.DENIED" -> :failed
      _ -> nil
    end
  end

  @doc """
  Process webhook events from PayPal.

  Args:
    * `event_type` - The PayPal event type
    * `resource` - The resource data from the webhook payload
    * `user_id` - The ID of the user associated with this webhook

  Returns:
    * `{:ok, subscription_state}` - The event was processed successfully
    * `{:error, reason}` - An error occurred while processing the event
  """
  def process_webhook_event(event_type, _resource, _user_id) do
    case map_event_to_state(event_type) do
      nil ->
        {:error, :unknown_event_type}

      state ->
        # This is a subscription-related event we want to process
        {:ok, state}
    end
  end
end
