defmodule Partners.Services.Paypal do
  @moduledoc """
  Service module for PayPal API interactions.
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
  def build_subscription_payload(user_id) do
    %{
      plan_id: plan_id(),
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

  Returns:
    * `{:ok, subscription_data}` - The subscription was successfully created
    * `{:error, reason}` - An error occurred while creating the subscription
  """
  def create_subscription(user_id) do
    with {:ok, token} <- get_access_token(),
         payload <- build_subscription_payload(user_id),
         response <- request_create_subscription(token, payload) do
      process_subscription_response(response)
    end
  end

  @doc """
  Extracts a specific link from a PayPal API response.
  """
  def extract_link(subscription_data, rel) do
    links = subscription_data["links"] || []

    link = Enum.find(links, fn link -> link["rel"] == rel end)

    case link do
      %{"href" => url} -> url
      _ -> nil
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
