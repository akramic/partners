defmodule Partners.Services.Paypal do
  @moduledoc """
  Service module for handling PayPal API interactions for subscription management.

  This module provides comprehensive functionality for integrating PayPal subscriptions
  with the Loving Partners dating app, including:

  - Creating subscription plans with 7-day free trials
    ```elixir
    # Setup a subscription plan during app initialization
    Partners.Services.Paypal.maybe_create_subscription_plan()
    # => {:ok, "P-123456789ABCDEF"} or {:ok, :plan_exists}
    ```

  - Managing the subscription lifecycle (creation, activation, suspension, cancellation)
    ```elixir
    # Creating a subscription for a user
    profile_id = "user_123"
    Partners.Services.Paypal.create_subscription_url(profile_id)
    # => {:ok, %{subscription_id: "I-123456789", approve_url: "https://paypal.com/approval"}}

    # Suspend a subscription
    Partners.Services.Paypal.suspend_subscription("I-123456789")
    # => {:ok, :suspended}

    # Reactivate a suspended subscription
    Partners.Services.Paypal.activate_subscription("I-123456789")
    # => {:ok, :activated}
    ```

  - Processing and verifying PayPal webhooks
    ```elixir
    # In a Phoenix controller
    def webhook(conn, _params) do
      Partners.Services.Paypal.handle_webhook(conn)
      # Verifies signature and processes webhook event
      send_resp(conn, 200, "OK")
    end
    ```

  - Tracking subscription status changes
    ```elixir
    # Check if a subscription is active
    Partners.Services.Paypal.subscription_active?("I-123456789")
    # => {:ok, subscription_details} or {:error, :suspended}

    # Update local user record with subscription status
    Partners.Services.Paypal.update_user_subscription_status("user_123", "I-123456789")
    # => {:ok, "ACTIVE"}
    ```

  - Broadcasting subscription events via PubSub
    ```elixir
    # Subscribe to events in a LiveView
    def mount(_params, _session, socket) do
      profile_id = socket.assigns.current_user.profile_id
      Phoenix.PubSub.subscribe(Partners.PubSub, "subscription:" <> profile_id)
      # ...
    end

    # Handle broadcasted events
    def handle_info({:subscription_updated, event_data}, socket) do
      # Update UI based on subscription changes
      {:noreply, assign(socket, subscription_status: event_data.status)}
    end
    ```

  ## Complete Subscription Flow

  The complete flow for implementing PayPal subscriptions is as follows:

  1. **Setup Phase** (done once during application deployment)
     ```elixir
     # 1. Create a product in PayPal (or use existing one)
     {:ok, product_id} = Partners.Services.Paypal.create_product()

     # 2. Create a subscription plan with that product
     {:ok, plan_id} = Partners.Services.Paypal.create_subscription_plan(product_id)

     # 3. Update the @subscription_plan_id_aud module attribute with this plan ID
     # 4. Configure the webhook in PayPal Developer Dashboard to point to your /webhooks/subscriptions/paypal endpoint
     ```

  2. **Subscription Creation** (when a user wants to subscribe)
     ```elixir
     # 1. Generate a subscription URL for the user
     {:ok, %{subscription_id: sub_id, approve_url: url}} =
       Partners.Services.Paypal.create_subscription_url(user.profile_id)

     # 2. Store the subscription_id in your database
     Repo.update(user, %{paypal_subscription_id: sub_id, subscription_status: "PENDING"})

     # 3. Redirect the user to the approve_url
     conn |> redirect(external: url)
     ```

  3. **Handle User Return** (after user approves/cancels on PayPal's site)
     ```elixir
     # Your WebhookController.subscription_return/2 function will handle:
     # - Success redirects to /subscriptions/paypal/success
     # - Cancel redirects to /subscriptions/paypal/cancel
     ```

  4. **Process Webhook Events** (for status updates)
     ```elixir
     # Your WebhookController.paypal/2 function will receive events like:
     # - PAYMENT.SALE.COMPLETED
     # - BILLING.SUBSCRIPTION.ACTIVATED
     # - BILLING.SUBSCRIPTION.CANCELLED
     # - BILLING.SUBSCRIPTION.SUSPENDED
     # - BILLING.SUBSCRIPTION.UPDATED
     #
     # These should be processed and broadcast to relevant parts of your app
     ```

  All API interactions use the `req` HTTP client and retrieve credentials from environment
  variables. The module supports both sandbox (development/testing) and production environments.

  ## Testing with PayPal Sandbox

  The PayPal Sandbox environment provides a complete testing ecosystem for PayPal integrations.
  Here's how to set up and test subscriptions with sandbox accounts:

  1. **Creating Sandbox Accounts**
     - Log in to the [PayPal Developer Dashboard](https://developer.paypal.com/dashboard/)
     - Navigate to "Sandbox" > "Accounts"
     - Create two accounts:
       - Business account (to receive payments)
       - Personal account (to make payments)

  2. **Testing Subscription Flow**
     - Use the personal sandbox account to approve subscriptions
     - Login credentials format: `sb-username@personal.example.com` with the password you set
     - For testing credit cards, you can use:
       - Card number: `4111111111111111`
       - Expiry date: Any future date
       - CVV: Any 3 digits

  3. **Simulating Webhook Events**
     - In the PayPal Developer Dashboard, go to "Webhooks" > "Simulator"
     - Select your webhook endpoint
     - Choose an event type (e.g., `PAYMENT.SALE.COMPLETED` or `BILLING.SUBSCRIPTION.ACTIVATED`)
     - Click "Send test webhook" to trigger the event

  4. **Verifying Sandbox Transactions**
     - Log in to the sandbox business account at [sandbox.paypal.com](https://sandbox.paypal.com)
     - View transactions, subscriptions, and payment details
     - Download transaction reports for reconciliation testing

  You can test the entire subscription flow by creating a subscription with
  `create_subscription_url/1`, approving it with a sandbox personal account, and then
  verifying the webhook events are processed correctly.

  ## Design Principles

  The module follows these key design principles:

  - **Single Responsibility**: Each function has a single, focused purpose
  - **Function Composition**: Complex operations are broken down into smaller, composable functions
  - **Consistent Error Handling**: All API interactions use the same error handling pattern
  - **Pure Data Transformation**: Data preparation is separated from IO operations
  - **Centralized HTTP Requests**: All HTTP communication goes through a single function

  ## Configuration

  Required environment variables:
  - `CLIENT_ID`: PayPal API client ID
  - `SECRET`: PayPal API secret
  - `PAYPAL_WEBHOOK_ID`: ID of the webhook configured in PayPal

  Optional configuration:
  - `:paypal_sandbox` - Boolean in application config that determines whether to use
    sandbox or production environments (defaults to `true`)
  """

  require Logger

  # Remove hardcoded constants and replace with config accessors

  @doc """
  Get PayPal API configuration from environment

  ## Returns

  Map containing:
  - `client_id`: PayPal API client ID from environment
  - `secret`: PayPal API secret from environment
  - `sandbox_mode`: Boolean indicating whether to use sandbox (test) mode
  """
  def config do
    client_id = get_client_id()
    secret = get_secret()

    # Debug output to check the credentials
    Logger.debug(
      "PayPal config - client_id present: #{!is_nil(client_id)}, secret present: #{!is_nil(secret)}"
    )

    # Check environment variables directly as a fallback
    client_id =
      if is_nil(client_id) do
        env_client_id = System.get_env("PAYPAL_CLIENT_ID")
        Logger.debug("Falling back to env PAYPAL_CLIENT_ID: #{!is_nil(env_client_id)}")
        env_client_id
      else
        client_id
      end

    secret =
      if is_nil(secret) do
        env_secret = System.get_env("PAYPAL_SECRET")
        Logger.debug("Falling back to env PAYPAL_SECRET: #{!is_nil(env_secret)}")
        env_secret
      else
        secret
      end

    %{
      client_id: client_id,
      secret: secret,
      # Determine sandbox vs live mode from config
      sandbox_mode: mode() == :sandbox,
      subscription_plan_id_aud: subscription_plan_id_aud()
    }
  end

  # Config accessor functions to simplify getting configuration values with fallbacks
  defp get_client_id, do: Application.get_env(:partners, __MODULE__)[:client_id]
  defp get_secret, do: Application.get_env(:partners, __MODULE__)[:secret]

  defp mode, do: Application.get_env(:partners, __MODULE__)[:mode] || :sandbox

  defp webhook_id do
    Application.get_env(:partners, __MODULE__)[:webhook_id]
  end

  def subscription_plan_id_aud do
    Application.get_env(:partners, __MODULE__)[:subscription_plan_id_aud]
  end

  # Get product ID from configuration
  defp product_id do
    Application.get_env(:partners, __MODULE__)[:product_id]
  end

  # Trial period in days (configurable with default of 7 days)
  defp trial_period_days do
    Application.get_env(:partners, __MODULE__)[:trial_period_days] || 7
  end

  # Base URL based on environment
  @doc """
  Get the base URL for PayPal API based on environment

  Uses the sandbox URL when in development/test environments and
  the production URL when in production environment.

  ## Returns

  String URL for PayPal API:
  - Sandbox: https://api-m.sandbox.paypal.com
  - Production: https://api-m.paypal.com
  """
  def base_url do
    case mode() do
      :live ->
        Application.get_env(:partners, __MODULE__)[:base_url] || "https://api-m.paypal.com"

      _ ->
        Application.get_env(:partners, __MODULE__)[:base_url] ||
          "https://api-m.sandbox.paypal.com"
    end
  end

  @doc """
  Tests authentication with PayPal API and returns detailed debugging information.

  This is a diagnostic function that attempts to authenticate with PayPal
  and returns detailed information about the process, including credentials
  used and the raw response.

  ## Returns

  - `{:ok, debug_info}` - Authentication successful with debug details
  - `{:error, reason, debug_info}` - Authentication failed with reason and debug details
  """
  def test_authentication do
    client_id = config().client_id
    secret = config().secret

    debug_info = %{
      client_id_provided: !is_nil(client_id),
      client_id_length: if(is_nil(client_id), do: 0, else: String.length(client_id)),
      secret_provided: !is_nil(secret),
      secret_length: if(is_nil(secret), do: 0, else: String.length(secret)),
      base_url: base_url(),
      manual_auth_header:
        if(is_nil(client_id) || is_nil(secret),
          do: nil,
          else: "Basic #{Base.encode64("#{client_id}:#{secret}")}"
        )
    }

    if is_nil(client_id) || is_nil(secret) do
      Logger.error(
        "PayPal test_authentication: client_id or secret is nil. Check your configuration."
      )

      {:error, :missing_credentials, debug_info}
    else
      url = "#{base_url()}/v1/oauth2/token"
      auth_string = Base.encode64("#{client_id}:#{secret}")

      Logger.debug("PayPal test_authentication: Making request to #{url}")

      Logger.debug(
        "PayPal test_authentication: Using auth header: Basic #{String.slice(auth_string, 0, 10)}..."
      )

      start_time = System.monotonic_time(:millisecond)

      response =
        Req.new(url: url)
        |> Req.Request.put_header("authorization", "Basic #{auth_string}")
        |> Req.Request.put_header("accept", "application/json")
        |> Req.Request.put_header("content-type", "application/x-www-form-urlencoded")
        |> Req.post(form: [grant_type: "client_credentials"])

      end_time = System.monotonic_time(:millisecond)

      response_debug =
        case response do
          {:ok, resp} ->
            %{
              status: resp.status,
              headers: resp.headers,
              body: resp.body,
              response_time_ms: end_time - start_time
            }

          {:error, error} ->
            %{error: inspect(error), response_time_ms: end_time - start_time}
        end

      debug_info = Map.put(debug_info, :response, response_debug)

      case response do
        {:ok, %{status: 200, body: body}} ->
          {:ok, Map.put(debug_info, :token, body["access_token"])}

        {:ok, %{status: status, body: body}} ->
          Logger.error("PayPal test_authentication failed: #{status} - #{inspect(body)}")
          {:error, :token_generation_failed, debug_info}

        {:error, exception} ->
          Logger.error("PayPal test_authentication request error: #{inspect(exception)}")
          {:error, :request_failed, debug_info}
      end
    end
  end

  # test_verify_plan_exists checks if our subscription plan exists and is valid
  @doc """
  Tests if the configured subscription plan exists and returns plan details.

  This is a diagnostic function that verifies the subscription plan configuration
  by attempting to retrieve the plan details from PayPal.

  ## Returns

  - `{:ok, plan_details}` - Plan exists and details are returned
  - `{:error, reason}` - Error occurred during plan verification
  """
  def test_verify_plan_exists do
    plan_id = subscription_plan_id_aud()

    if is_nil(plan_id) do
      {:error, :missing_plan_id}
    else
      case get_subscription_plan(plan_id) do
        {:ok, plan} -> {:ok, plan}
        error -> error
      end
    end
  end

  @doc """
  Generate an access token for PayPal API calls.

  Uses client credentials grant type with Basic authentication to retrieve an OAuth token
  from the PayPal API. This token is required for all subsequent API requests.

  ## Returns

  - `{:ok, token}` - Successfully generated token as a string
  - `{:error, :token_generation_failed}` - Server responded but token generation failed
  - `{:error, :request_failed}` - Request to PayPal failed
  """
  def generate_access_token do
    client_id = config().client_id
    secret = config().secret

    # Check for nil credentials
    if is_nil(client_id) || is_nil(secret) do
      Logger.error("PayPal client_id or secret is nil. Check your configuration.")
      {:error, :missing_credentials}
    else
      url = "#{base_url()}/v1/oauth2/token"

      # Create Base64 encoded auth header manually (client_id:secret)
      auth_string = Base.encode64("#{client_id}:#{secret}")

      # This is a special case that doesn't use api_request because it needs basic auth
      # and different content-type
      response =
        Req.new(url: url)
        |> Req.Request.put_header("authorization", "Basic #{auth_string}")
        |> Req.Request.put_header("accept", "application/json")
        |> Req.Request.put_header("content-type", "application/x-www-form-urlencoded")
        |> Req.post(form: [grant_type: "client_credentials"])

      case response do
        {:ok, %{status: 200, body: body}} ->
          {:ok, body["access_token"]}

        {:ok, %{status: status, body: body}} ->
          Logger.error("Failed to generate PayPal access token: #{status} - #{inspect(body)}")
          {:error, :token_generation_failed}

        {:error, exception} ->
          Logger.error("PayPal token request error: #{inspect(exception)}")
          {:error, :request_failed}
      end
    end
  end

  @doc """
  Creates a subscription plan in PayPal if it doesn't exist.

  This function should be called during application startup to ensure the required
  subscription plan exists in PayPal. It checks for an existing plan with the
  ID stored in `@subscription_plan_id_aud` and creates one if needed.

  ## Returns

  - `{:ok, :plan_exists}` - The plan already exists in PayPal
  - `{:ok, plan_id}` - Successfully created a new plan, returns the plan ID
  - `{:error, reason}` - Failed to create or verify the plan
  """
  def maybe_create_subscription_plan(product_id \\ nil) do
    case get_subscription_plan(subscription_plan_id_aud()) do
      {:ok, _plan} ->
        {:ok, :plan_exists}

      {:error, :not_found} ->
        create_subscription_plan(product_id)

      error ->
        error
    end
  end

  @doc """
  Get a subscription plan by ID from PayPal

  Retrieves the details of a specific subscription plan from PayPal.

  ## Parameters

  - `plan_id` - String identifier of the PayPal plan to retrieve

  ## Returns

  - `{:ok, plan}` - Successfully retrieved plan details as a map
  - `{:error, :not_found}` - Plan with the given ID doesn't exist
  - `{:error, :plan_fetch_failed}` - PayPal returned an error response
  - `{:error, :request_failed}` - HTTP request to PayPal failed
  """
  def get_subscription_plan(plan_id) do
    case api_request(:get, "/v1/billing/plans/#{plan_id}") do
      {:ok, body} ->
        {:ok, body}

      {:error, :not_found} = error ->
        error

      {:error, {:api_error, _status, _body}} ->
        {:error, :plan_fetch_failed}

      error ->
        error
    end
  end

  @doc """
  Creates a subscription plan in PayPal.

  Sets up a monthly subscription plan with a 7-day free trial followed by regular
  monthly billing at $19 AUD. The trial period length is defined by `@trial_period_days`
  and the regular price by `@subscription_price_aud`.

  If a product_id is provided, it will use that product. Otherwise, it will create
  a new product in PayPal and then create a billing plan attached to that product.

  ## Parameters

  - `product_id` - Optional String identifier of an existing PayPal product to use

  ## Returns

  - `{:ok, plan_id}` - Successfully created plan, returns the plan ID
  - `{:error, :plan_creation_failed}` - PayPal returned an error response
  - `{:error, :request_failed}` - HTTP request to PayPal failed
  - `{:error, :product_creation_failed}` - Failed to create the required product
  """
  def create_subscription_plan(product_id \\ nil) do
    # Use the provided product_id, or the configured one, or create a new one
    configured_product_id = product_id()

    product_result =
      cond do
        product_id != nil -> {:ok, product_id}
        configured_product_id != nil -> {:ok, configured_product_id}
        true -> create_product()
      end

    with {:ok, product_id} <- product_result,
         {:ok, plan_payload} <- build_plan_payload(product_id),
         headers = [{"prefer", "return=representation"}],
         {:ok, body} <-
           api_request(:post, "/v1/billing/plans", json: plan_payload, headers: headers) do
      # Store the plan ID for future use
      Logger.info("Created PayPal subscription plan: #{body["id"]}")
      {:ok, body["id"]}
    else
      {:error, :product_creation_failed} = error -> error
      {:error, :api_error} -> {:error, :plan_creation_failed}
      {:error, {:api_error, _status, _body}} -> {:error, :plan_creation_failed}
      error -> error
    end
  end

  # Build the payload for creating a subscription plan
  defp build_plan_payload(product_id) do
    plan_payload = %{
      product_id: product_id,
      name: "Loving Partners Monthly Subscription",
      description: "Premium monthly subscription to Loving Partners dating service",
      status: "ACTIVE",
      billing_cycles: [
        build_trial_cycle(),
        build_regular_cycle()
      ],
      payment_preferences: %{
        auto_bill_outstanding: true,
        setup_fee: %{
          value: "0.00",
          currency_code: "AUD"
        },
        setup_fee_failure_action: "CONTINUE",
        payment_failure_threshold: 3
      },
      taxes: %{
        # GST in Australia
        percentage: "10",
        inclusive: true
      }
    }

    {:ok, plan_payload}
  end

  # Build the trial billing cycle
  defp build_trial_cycle do
    %{
      frequency: %{
        interval_unit: "MONTH",
        interval_count: 1
      },
      tenure_type: "TRIAL",
      sequence: 1,
      total_cycles: 1,
      pricing_scheme: %{
        fixed_price: %{
          value: "0.00",
          currency_code: "AUD"
        }
      }
    }
  end

  # Build the regular (post-trial) billing cycle
  defp build_regular_cycle do
    %{
      frequency: %{
        interval_unit: "MONTH",
        interval_count: 1
      },
      tenure_type: "REGULAR",
      sequence: 2,
      # Infinite
      total_cycles: 0,
      pricing_scheme: %{
        fixed_price: %{
          value: "19.00",
          currency_code: "AUD"
        }
      }
    }
  end

  @doc """
  Creates a product in PayPal to be used with subscription plans.

  Creates a "Loving Partners Premium" product in PayPal that can be associated
  with subscription plans. Each plan must be connected to a product.

  ## Returns

  - `{:ok, product_id}` - Successfully created product, returns the product ID
  - `{:error, :product_creation_failed}` - PayPal returned an error response
  - `{:error, :request_failed}` - HTTP request to PayPal failed
  """
  def create_product do
    with {:ok, token} <- generate_access_token() do
      product_payload = %{
        name: "Loving Partners Premium",
        description: "Premium access to Loving Partners dating service",
        type: "SERVICE"
        # Removed additional fields to keep it minimal
      }

      headers = [
        {"prefer", "return=representation"},
        {"authorization", "Bearer #{token}"},
        {"content-type", "application/json"}
      ]

      url = "#{base_url()}/v1/catalogs/products"

      response = Req.post(url, json: product_payload, headers: headers)

      case response do
        {:ok, %{status: status, body: body}} when status in 200..204 ->
          {:ok, body["id"]}

        {:ok, %{status: status, body: body}} ->
          Logger.error("Failed to create PayPal product: #{status} - #{inspect(body)}")
          {:error, :product_creation_failed}

        {:error, exception} ->
          Logger.error("PayPal request error: #{inspect(exception)}")
          {:error, :request_failed}
      end
    end
  end

  @doc """
  Creates a subscription URL for a user that will redirect them to PayPal
  to set up a subscription with a 7-day free trial.

  This generates a PayPal-hosted checkout page URL where the user can approve
  the subscription. After approval, PayPal redirects the user back to the appropriate
  URL in your application.

  ## Parameters

  - `profile_id` - String identifier of the user's profile, stored as custom_id in PayPal
  - `base_url` - Optional base URL for the return and cancel URLs. If not provided,
    it will use "http://localhost:4000" in development and the configured production
    URL in production.

  ## Returns

  - `{:ok, %{subscription_id: id, approve_url: url}}` - Successfully created subscription
    with the PayPal subscription ID and approval URL
  - `{:error, :subscription_creation_failed}` - PayPal returned an error response
  - `{:error, :request_failed}` - HTTP request to PayPal failed
  """
  def create_subscription_url(profile_id, base_url \\ nil) do
    # First check if we have valid credentials
    case generate_access_token() do
      {:error, :missing_credentials} ->
        {:error, "PayPal client_id or secret is nil. Check your configuration."}

      _ ->
        base_url = base_url || default_base_url()
        return_url = "#{base_url}/subscriptions/paypal/success"
        cancel_url = "#{base_url}/subscriptions/paypal/cancel"

        with {:ok, payload} <- build_subscription_payload(profile_id, return_url, cancel_url),
             headers = [{"prefer", "return=representation"}],
             {:ok, body} <-
               api_request(:post, "/v1/billing/subscriptions", json: payload, headers: headers) do
          {:ok,
           %{
             subscription_id: body["id"],
             approve_url: find_approve_url(body)
           }}
        else
          {:error, {:api_error, _status, _body}} ->
            {:error, :subscription_creation_failed}

          error ->
            error
        end
    end
  end

  # Get default base URL based on environment
  defp default_base_url do
    # Use the return_url_base from configuration
    Application.get_env(:partners, __MODULE__)[:return_url_base] ||
      if config().sandbox_mode do
        "http://localhost:4000"
      else
        "https://lovingpartners.com.au"
      end
  end

  # Build the payload for creating a subscription
  defp build_subscription_payload(profile_id, return_url, cancel_url) do
    # Calculate start time after trial period
    start_time =
      DateTime.utc_now()
      |> DateTime.add(trial_period_days(), :day)
      |> DateTime.to_iso8601()

    payload = %{
      plan_id: subscription_plan_id_aud(),
      start_time: start_time,
      custom_id: profile_id,
      application_context: %{
        brand_name: "Loving Partners",
        locale: "en-AU",
        shipping_preference: "NO_SHIPPING",
        user_action: "SUBSCRIBE_NOW",
        payment_method: %{
          payer_selected: "PAYPAL",
          payee_preferred: "IMMEDIATE_PAYMENT_REQUIRED"
        },
        return_url: return_url,
        cancel_url: cancel_url
      }
    }

    {:ok, payload}
  end

  # Helper function to find the approval URL from PayPal response links
  #
  # In PayPal API responses, the approval URL is included in the links array
  # with the relation type "approve". This function extracts that URL.
  #
  # ## Parameters
  # - response: Map containing links array from PayPal response
  #
  # ## Returns
  # - String URL where the user should be redirected to approve the subscription
  defp find_approve_url(%{"links" => links}) when is_list(links) do
    approve_link = Enum.find(links, fn link -> link["rel"] == "approve" end)
    if approve_link, do: approve_link["href"], else: nil
  end

  defp find_approve_url(_), do: nil

  @doc """
  Get subscription details by subscription ID

  Retrieves the current details of a subscription from PayPal.

  ## Parameters

  - `subscription_id` - String identifier of the PayPal subscription

  ## Returns

  - `{:ok, subscription}` - Successfully retrieved subscription details as a map
  - `{:error, :not_found}` - Subscription with the given ID doesn't exist
  - `{:error, :subscription_fetch_failed}` - PayPal returned an error response
  - `{:error, :request_failed}` - HTTP request to PayPal failed
  """
  def get_subscription(subscription_id) do
    case api_request(:get, "/v1/billing/subscriptions/#{subscription_id}") do
      {:ok, body} ->
        {:ok, body}

      {:error, :not_found} = error ->
        error

      {:error, {:api_error, _status, _body}} ->
        {:error, :subscription_fetch_failed}

      error ->
        error
    end
  end

  @doc """
  Find subscription by profile ID (custom_id)

  PayPal doesn't provide a direct API to search for subscriptions by custom_id.
  In a complete implementation, this would query a local database where subscription IDs
  are stored with their associated profile IDs.

  ## Parameters

  - `profile_id` - String identifier of the user's profile

  ## Returns

  Currently returns `{:error, :not_implemented}` as a placeholder.
  In an actual implementation would return:
  - `{:ok, subscription}` - Successfully found subscription
  - `{:error, :not_found}` - No subscription found for this profile_id
  """
  def get_subscription_by_profile_id(_profile_id) do
    # Note: PayPal doesn't directly support searching by custom_id
    # In a real implementation, you would store the subscription_id in your database
    # when creating the subscription, then look it up by profile_id
    # This is a placeholder for that logic
    {:error, :not_implemented}
  end

  @doc """
  Cancel a subscription

  Cancels an active PayPal subscription. The subscription will remain active until
  the end of the current billing period unless immediate cancellation is required.

  ## Parameters

  - `subscription_id` - String identifier of the PayPal subscription
  - `reason` - Optional reason for cancellation, defaults to "Customer requested cancellation"

  ## Returns

  - `{:ok, :cancelled}` - Successfully cancelled the subscription
  - `{:error, :cancellation_failed}` - PayPal returned an error response
  - `{:error, :request_failed}` - HTTP request to PayPal failed
  """
  def cancel_subscription(subscription_id, reason \\ "Customer requested cancellation") do
    case api_request(:post, "/v1/billing/subscriptions/#{subscription_id}/cancel",
           json: %{reason: reason}
         ) do
      {:ok, _} ->
        {:ok, :cancelled}

      {:error, {:api_error, _status, _body}} ->
        {:error, :cancellation_failed}

      error ->
        error
    end
  end

  @doc """
  Suspend a subscription (pause billing)

  Temporarily suspends a PayPal subscription, pausing billing but keeping
  the subscription record active. Can be reactivated later.

  ## Parameters

  - `subscription_id` - String identifier of the PayPal subscription
  - `reason` - Optional reason for suspension, defaults to "Subscription suspended"

  ## Returns

  - `{:ok, :suspended}` - Successfully suspended the subscription
  - `{:error, :suspension_failed}` - PayPal returned an error response
  - `{:error, :request_failed}` - HTTP request to PayPal failed
  """
  def suspend_subscription(subscription_id, reason \\ "Subscription suspended") do
    case api_request(:post, "/v1/billing/subscriptions/#{subscription_id}/suspend",
           json: %{reason: reason}
         ) do
      {:ok, _} ->
        {:ok, :suspended}

      {:error, {:api_error, _status, _body}} ->
        {:error, :suspension_failed}

      error ->
        error
    end
  end

  @doc """
  Activate a suspended subscription

  Reactivates a previously suspended PayPal subscription, resuming billing.

  ## Parameters

  - `subscription_id` - String identifier of the PayPal subscription
  - `reason` - Optional reason for activation, defaults to "Subscription reactivated"

  ## Returns

  - `{:ok, :activated}` - Successfully activated the subscription
  - `{:error, :activation_failed}` - PayPal returned an error response
  - `{:error, :request_failed}` - HTTP request to PayPal failed
  """
  def activate_subscription(subscription_id, reason \\ "Subscription reactivated") do
    case api_request(:post, "/v1/billing/subscriptions/#{subscription_id}/activate",
           json: %{reason: reason}
         ) do
      {:ok, _} ->
        {:ok, :activated}

      {:error, {:api_error, _status, _body}} ->
        {:error, :activation_failed}

      error ->
        error
    end
  end

  @doc """
  Process a webhook notification from PayPal

  This function verifies the webhook authenticity, parses the event data, and
  broadcasts relevant events via PubSub for real-time updates in the application.

  It follows a pipeline of operations:
  1. Verify webhook signature
  2. Parse webhook payload
  3. Extract profile_id
  4. Process and broadcast event

  ## Parameters

  - `payload` - Raw request body from PayPal webhook (JSON string)
  - `headers` - Map of HTTP headers from the webhook request, must include:
    - `paypal-cert-url`
    - `paypal-transmission-id`
    - `paypal-transmission-time`
    - `paypal-transmission-sig`
    - `paypal-auth-algo` (optional, defaults to "SHA256withRSA")

  ## Returns

  - `{:ok, event}` - Successfully processed and broadcasted the event
  - `{:error, :invalid_signature}` - Webhook signature verification failed
  - `{:error, :invalid_json}` - Payload isn't valid JSON
  - `{:error, :invalid_payload}` - Payload doesn't have the expected structure
  - Various other error tuples from verification process
  """
  def process_webhook(payload, headers) do
    with :ok <- verify_webhook_signature(payload, headers),
         {:ok, event} <- parse_webhook_event(payload),
         {:ok, event_with_profile} <- extract_and_validate_profile_id(event),
         :ok <- broadcast_webhook_event(event_with_profile) do
      {:ok, event}
    end
  end

  # Extract profile_id and validate its presence
  defp extract_and_validate_profile_id(event) do
    case get_profile_id_from_event(event) do
      nil ->
        Logger.error("PayPal webhook missing profile_id: #{inspect(event)}")
        {:error, :missing_profile_id}

      profile_id ->
        {:ok, Map.put(event, "profile_id", profile_id)}
    end
  end

  # Handle broadcasting of webhook events
  defp broadcast_webhook_event(event) do
    profile_id = event["profile_id"]
    broadcast_subscription_event(profile_id, event)
    :ok
  end

  @doc """
  Verify the authenticity of a PayPal webhook using their Webhook Verification API

  This follows PayPal's recommended process to verify the signature of incoming webhooks
  to ensure they're genuinely from PayPal. The function validates the digital signature
  provided in the webhook headers against the webhook ID configured in the environment.

  ## Parameters

  - `payload` - Raw request body from PayPal webhook (JSON string)
  - `headers` - Map of HTTP headers from the webhook request, must include:
    - `paypal-cert-url`
    - `paypal-transmission-id`
    - `paypal-transmission-time`
    - `paypal-transmission-sig`
    - `paypal-auth-algo` (optional, defaults to "SHA256withRSA")

  ## Returns

  - `:ok` - Webhook signature is valid
  - `{:error, :invalid_signature}` - Signature verification failed
  - `{:error, :verification_failed}` - PayPal API returned an error response
  - `{:error, :request_failed}` - HTTP request to PayPal failed
  - `{:error, :webhook_id_not_configured}` - Missing webhook ID in environment
  - `{:error, :missing_required_headers}` - Missing required headers for verification
  """
  def verify_webhook_signature(payload, headers) do
    with {:ok, token} <- generate_access_token(),
         {:ok, webhook_id} <- get_webhook_id(),
         {:ok, verification_payload} <- build_verification_payload(payload, headers, webhook_id) do
      url = "#{base_url()}/v1/notifications/verify-webhook-signature"

      response =
        Req.new(url: url)
        |> Req.Request.put_header("authorization", "Bearer #{token}")
        |> Req.Request.put_header("content-type", "application/json")
        |> Req.post(json: verification_payload)

      case response do
        {:ok, %{status: 200, body: %{"verification_status" => "SUCCESS"}}} ->
          :ok

        {:ok, %{status: 200, body: %{"verification_status" => status}}} ->
          Logger.warning("PayPal webhook signature verification failed with status: #{status}")
          {:error, :invalid_signature}

        {:ok, %{status: status, body: body}} ->
          Logger.error("Failed to verify PayPal webhook signature: #{status} - #{inspect(body)}")
          {:error, :verification_failed}

        {:error, exception} ->
          Logger.error("PayPal webhook verification error: #{inspect(exception)}")
          {:error, :request_failed}
      end
    end
  end

  # Get webhook ID from configuration
  #
  # Retrieves the PayPal webhook ID from environment variables.
  # This ID is required for webhook signature verification.
  #
  # ## Returns
  # - {:ok, webhook_id} - Successfully retrieved webhook ID
  # - {:error, :webhook_id_not_configured} - Webhook ID not set in environment
  defp get_webhook_id do
    webhook_id = webhook_id()
    if webhook_id, do: {:ok, webhook_id}, else: {:error, :webhook_id_not_configured}
  end

  # Build the payload for webhook signature verification
  #
  # Creates the verification payload required by PayPal's verification API.
  #
  # ## Parameters
  # - payload: Raw webhook payload (JSON string)
  # - headers: Map containing required PayPal headers
  # - webhook_id: ID of the configured webhook in PayPal
  #
  # ## Returns
  # - {:ok, payload_map} - Valid verification payload
  # - {:error, :missing_required_headers} - Missing one or more required headers
  defp build_verification_payload(payload, headers, webhook_id) do
    # Extract required headers for verification
    cert_url = headers["paypal-cert-url"]
    transmission_id = headers["paypal-transmission-id"]
    timestamp = headers["paypal-transmission-time"]
    signature = headers["paypal-transmission-sig"]

    if Enum.all?([cert_url, transmission_id, timestamp, signature], &(not is_nil(&1))) do
      verification_payload = %{
        "webhook_id" => webhook_id,
        "transmission_id" => transmission_id,
        "transmission_time" => timestamp,
        "cert_url" => cert_url,
        "auth_algo" => headers["paypal-auth-algo"] || "SHA256withRSA",
        "transmission_sig" => signature,
        "webhook_event" => Jason.decode!(payload)
      }

      {:ok, verification_payload}
    else
      Logger.error("Missing required PayPal webhook headers")
      {:error, :missing_required_headers}
    end
  end

  # Parse webhook event from payload
  #
  # Converts the webhook payload to a map structure for processing.
  # Handles both string (JSON) and map inputs.
  #
  # ## Returns
  # - {:ok, event_map} - Successfully parsed event
  # - {:error, :invalid_json} - Payload isn't valid JSON
  # - {:error, :invalid_payload} - Payload isn't the expected type
  defp parse_webhook_event(payload) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _} -> {:error, :invalid_json}
    end
  end

  defp parse_webhook_event(payload) when is_map(payload), do: {:ok, payload}
  defp parse_webhook_event(_), do: {:error, :invalid_payload}

  # Extract profile ID from the webhook event
  #
  # The profile ID was stored in custom_id when creating the subscription.
  # This function extracts it from the webhook event's resource.
  #
  # ## Returns
  # - String profile ID if found
  # - nil if not found
  defp get_profile_id_from_event(%{"resource" => %{"custom_id" => custom_id}})
       when is_binary(custom_id) do
    custom_id
  end

  defp get_profile_id_from_event(_), do: nil

  # Broadcast subscription events via PubSub for real-time updates
  #
  # This function:
  # 1. Builds an event data structure with relevant information
  # 2. Processes the event based on its type
  # 3. Broadcasts the event to profile-specific and general channels
  #
  # ## Parameters
  # - profile_id: ID of the user's profile
  # - event: Raw webhook event from PayPal
  #
  # ## Returns
  # - :ok
  defp broadcast_subscription_event(profile_id, event) do
    event_type = event["event_type"]
    subscription_id = get_in(event, ["resource", "id"])

    event_data = %{
      profile_id: profile_id,
      subscription_id: subscription_id,
      event_type: event_type,
      status: get_in(event, ["resource", "status"]),
      timestamp: get_in(event, ["create_time"]),
      raw_event: event
    }

    # Process specific event types and take appropriate actions
    process_subscription_event(event_type, event_data)

    # Broadcast to a channel specific to this profile's subscriptions
    Phoenix.PubSub.broadcast(
      Partners.PubSub,
      "subscription:#{profile_id}",
      {:subscription_updated, event_data}
    )

    # Also broadcast to a general channel for admin monitoring
    Phoenix.PubSub.broadcast(
      Partners.PubSub,
      "subscriptions",
      {:subscription_event, event_data}
    )

    :ok
  end

  # Handle different types of subscription events
  #
  # This function implements business logic for various PayPal subscription events.
  # Each event type triggers appropriate actions in the application.
  #
  # ## Parameters
  # - event_type: String identifier of the event type from PayPal
  # - event_data: Map containing processed event information
  #
  # ## Event Types Handled
  # - BILLING.SUBSCRIPTION.CREATED - New subscription created
  # - BILLING.SUBSCRIPTION.ACTIVATED - Subscription activated
  # - BILLING.SUBSCRIPTION.UPDATED - Subscription details changed
  # - BILLING.SUBSCRIPTION.SUSPENDED - Subscription temporarily suspended
  # - BILLING.SUBSCRIPTION.CANCELLED - Subscription cancelled
  # - BILLING.SUBSCRIPTION.EXPIRED - Subscription ended
  # - BILLING.SUBSCRIPTION.PAYMENT.FAILED - Payment attempt failed
  # - BILLING.SUBSCRIPTION.PAYMENT.SUCCEEDED - Payment successful
  defp process_subscription_event(event_type, event_data) do
    case event_type do
      "BILLING.SUBSCRIPTION.CREATED" ->
        # A subscription has been created but not yet activated
        Logger.info("Subscription created for profile: #{event_data.profile_id}")

      # Here you might want to update the user's record to note that
      # they've initiated a subscription

      "BILLING.SUBSCRIPTION.ACTIVATED" ->
        # Subscription has been activated (payment authorized)
        Logger.info("Subscription activated for profile: #{event_data.profile_id}")

      # Update the user's subscription status to active
      # Enable premium features for the user

      "BILLING.SUBSCRIPTION.UPDATED" ->
        # Subscription details have changed
        Logger.info("Subscription updated for profile: #{event_data.profile_id}")

      # Update subscription details in your database

      "BILLING.SUBSCRIPTION.SUSPENDED" ->
        # Subscription has been suspended (e.g. payment failure)
        Logger.warning("Subscription suspended for profile: #{event_data.profile_id}")

      # Disable premium features but don't delete the account

      "BILLING.SUBSCRIPTION.CANCELLED" ->
        # Subscription has been cancelled
        Logger.info("Subscription cancelled for profile: #{event_data.profile_id}")

      # Mark subscription as cancelled in your database
      # May want to schedule removal of premium features at end of current billing period

      "BILLING.SUBSCRIPTION.EXPIRED" ->
        # Subscription has reached its end date
        Logger.info("Subscription expired for profile: #{event_data.profile_id}")

      # Remove premium features from the user's account

      "BILLING.SUBSCRIPTION.PAYMENT.FAILED" ->
        # A payment attempt has failed
        Logger.warning("Subscription payment failed for profile: #{event_data.profile_id}")

      # Maybe send an email to the user about the payment failure

      "BILLING.SUBSCRIPTION.PAYMENT.SUCCEEDED" ->
        # A payment was successful
        Logger.info("Subscription payment succeeded for profile: #{event_data.profile_id}")

      # Update next_billing_date in your database

      _ ->
        # Other events that we're receiving but not specifically handling
        Logger.debug(
          "Received unhandled PayPal webhook event: #{event_type} for profile: #{event_data.profile_id}"
        )
    end
  end

  @doc """
  Check if a subscription is active and valid

  Retrieves the subscription from PayPal and checks its status to determine
  if it's currently active (either fully active or in approved trial state).

  ## Parameters

  - `subscription_id` - String identifier of the PayPal subscription

  ## Returns

  - `{:ok, subscription}` - Subscription is active, returns the full subscription data
  - `{:error, :suspended}` - Subscription is temporarily suspended
  - `{:error, :cancelled}` - Subscription has been cancelled
  - `{:error, :expired}` - Subscription has reached its end date
  - `{:error, {:invalid_status, status}}` - Subscription has an unexpected status
  - Other error tuples from `get_subscription/1`
  """
  def subscription_active?(subscription_id) do
    with {:ok, subscription} <- get_subscription(subscription_id) do
      status = subscription["status"]

      case status do
        "ACTIVE" ->
          # Subscription is active and in good standing
          {:ok, subscription}

        "APPROVED" ->
          # Subscription has been approved but hasn't started billing yet
          # (likely in trial period)
          {:ok, subscription}

        "SUSPENDED" ->
          # Subscription is temporarily suspended
          {:error, :suspended}

        "CANCELLED" ->
          # Subscription has been cancelled
          {:error, :cancelled}

        "EXPIRED" ->
          # Subscription has reached its end date
          {:error, :expired}

        _ ->
          # Any other status means the subscription is not active
          {:error, {:invalid_status, status}}
      end
    end
  end

  @doc """
  Update local user record based on subscription status

  This would be called after receiving a webhook or when checking subscription status
  manually. It ensures your local database stays in sync with PayPal's subscription
  status. Currently implemented as a placeholder.

  ## Parameters

  - `profile_id` - String identifier of the user's profile
  - `subscription_id` - String identifier of the PayPal subscription

  ## Returns

  - `{:ok, status}` - Successfully updated user record, returns the subscription status
  - Error tuples from `get_subscription/1`

  ## Notes

  This is a placeholder function. In a complete implementation, it would update
  the user's subscription information in your database.
  """
  def update_user_subscription_status(profile_id, subscription_id) do
    # This is a placeholder for updating the user's subscription status
    # In a real implementation, you would:
    # 1. Get the subscription from PayPal
    # 2. Update your local user record with the new status
    # 3. Apply business logic based on subscription status
    #    (e.g., enable/disable premium features)

    with {:ok, subscription} <- get_subscription(subscription_id) do
      # Extract useful data from the subscription
      status = subscription["status"]

      # Get billing dates
      _last_payment = get_in(subscription, ["billing_info", "last_payment", "time"])
      _next_billing = get_in(subscription, ["billing_info", "next_billing_time"])

      # Here you would update your user record with this information
      # For example: Partners.Accounts.update_user_subscription(profile_id, %{
      #   subscription_status: status,
      #   subscription_id: subscription_id,
      #   subscription_last_updated: DateTime.utc_now()
      # })

      # Return {:ok, status}
      {:ok, status}
    end
  end

  @doc """
  Handle webhook events from PayPal.

  Validates and processes incoming webhook events from PayPal. This function
  extracts the request body and headers, verifies the signature, and processes
  the webhook event.

  ## Returns

  - `{:ok, event}` - Successfully processed webhook event
  - `{:error, reason}` - Failed to process webhook for various reasons
  """
  def handle_webhook(conn) do
    # Extract the raw body and headers needed for verification
    {:ok, raw_body, conn} = Plug.Conn.read_body(conn)

    # Extract necessary headers
    headers = %{
      "paypal-auth-algo" => Plug.Conn.get_req_header(conn, "paypal-auth-algo") |> List.first(),
      "paypal-cert-url" => Plug.Conn.get_req_header(conn, "paypal-cert-url") |> List.first(),
      "paypal-transmission-id" =>
        Plug.Conn.get_req_header(conn, "paypal-transmission-id") |> List.first(),
      "paypal-transmission-sig" =>
        Plug.Conn.get_req_header(conn, "paypal-transmission-sig") |> List.first(),
      "paypal-transmission-time" =>
        Plug.Conn.get_req_header(conn, "paypal-transmission-time") |> List.first()
    }

    # Verify and process the webhook
    case process_webhook(raw_body, headers) do
      {:ok, event} ->
        # Successfully processed the webhook
        Logger.info("Processed PayPal webhook: #{event["event_type"]}")
        {:ok, event}

      {:error, reason} ->
        # Failed to process the webhook
        Logger.error("Failed to process PayPal webhook: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # API Client functionality

  @doc """
  Makes an authenticated HTTP request to the PayPal API.

  This centralizes all HTTP requests to PayPal API to ensure consistency in
  authentication, headers, and error handling.

  ## Parameters

  - `method` - HTTP method (:get, :post, :patch, etc.)
  - `path` - API path (will be appended to base_url)
  - `opts` - Options list which may include:
    - `:json` - Map to be sent as JSON body
    - `:form` - Keyword list to be sent as form data
    - `:headers` - Additional headers to include
    - `:basic_auth` - Boolean, if true use basic auth instead of token

  ## Returns

  - `{:ok, response_body}` - Successfully made request, returns response body
  - `{:error, :request_failed}` - HTTP request failed
  - Other error tuples from called functions
  """
  def api_request(method, path, opts \\ []) do
    # Extract and transform options
    req_opts = Keyword.take(opts, [:json, :form])
    headers = Keyword.get(opts, :headers, [])
    use_basic_auth = Keyword.get(opts, :basic_auth, false)

    url = "#{base_url()}#{path}"

    # Build the request with appropriate authentication
    request_with_auth =
      if use_basic_auth do
        client_id = config().client_id
        secret = config().secret

        if is_nil(client_id) || is_nil(secret) do
          {:error, :missing_credentials}
        else
          # Create Base64 encoded auth header manually (client_id:secret)
          auth_string = Base.encode64("#{client_id}:#{secret}")

          Req.new(url: url)
          |> Req.Request.put_header("authorization", "Basic #{auth_string}")
        end
      else
        with {:ok, token} <- generate_access_token() do
          Req.new(url: url)
          |> Req.Request.put_header("authorization", "Bearer #{token}")
        end
      end

    case request_with_auth do
      %Req.Request{} = req ->
        # Add common headers
        req =
          req
          |> Req.Request.put_header("content-type", "application/json")
          |> add_headers(headers)

        # Make the request
        case apply(Req, method, [req, req_opts]) do
          {:ok, %{status: status, body: body}} when status in 200..204 ->
            {:ok, body}

          {:ok, %{status: 404}} ->
            {:error, :not_found}

          {:ok, %{status: status, body: body}} ->
            Logger.error(
              "PayPal API error: #{method} #{path} returned #{status} - #{inspect(body)}"
            )

            {:error, {:api_error, status, body}}

          {:error, exception} ->
            Logger.error("PayPal request error: #{method} #{path} - #{inspect(exception)}")
            {:error, :request_failed}
        end

      error ->
        error
    end
  end

  # Adds multiple headers to a request
  defp add_headers(req, headers) do
    Enum.reduce(headers, req, fn {key, value}, acc ->
      Req.Request.put_header(acc, key, value)
    end)
  end
end
