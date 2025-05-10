defmodule PartnersWeb.Api.Webhooks.PaypalWebhookController do
  @moduledoc """
  Controller for handling PayPal webhook callbacks and subscription events.

  This controller is responsible for:
  - Receiving and validating PayPal webhook events
  - Processing subscription status changes
  - Broadcasting events via PubSub to relevant subscribers
  - Handling subscription return URLs (success/cancel)

  ## Event Broadcasting

  The controller broadcasts two types of events:
  1. Profile-specific events on topic "subscription:[profile_id]"
     Message: {:subscription_updated, event_data}
  2. Global events on topic "subscriptions"
     Message: {:subscription_event, event_data}

  LiveViews can subscribe to these events using:
      Phoenix.PubSub.subscribe(Partners.PubSub, "subscription:" <> profile_id)
  """
  use PartnersWeb, :controller
  require Logger

  alias Partners.Services.Paypal

  @doc """
  Handle PayPal subscription webhook callbacks.

  Processes incoming webhook notifications from PayPal by:
  1. Accessing the raw request body (cached by CacheRawBodyPlug)
  2. Retrieving necessary headers and PayPal Webhook ID
  3. Verifying the webhook signature (TODO)
  4. Processing through Partners.Services.Paypal.process_webhook
  5. Broadcasting to appropriate PubSub channels

  Always returns 200 OK (PayPal best practice) but logs any processing errors.
  """
  def paypal(conn, params) do
    # Raw body is now expected to be in conn.assigns.raw_body thanks to CacheRawBodyPlug
    raw_body = conn.assigns[:raw_body]

    # Fetch the configured PayPal Webhook ID
    paypal_webhook_id =
      try do
        Paypal.webhook_id()
      rescue
        e ->
          Logger.error("Failed to fetch PayPal Webhook ID: #{inspect(e)}")
          # Provide a default or handle error appropriately if critical for logging/verification
          "ERROR_FETCHING_WEBHOOK_ID"
      end

    # Log initial webhook receipt
    Logger.info("""
    🔔 WEBHOOK: Received PayPal webhook
    Raw Body (from assigns): #{inspect(raw_body)}
    PayPal Webhook ID (from config): #{inspect(paypal_webhook_id)}
    Headers: #{inspect(conn.req_headers, pretty: true)}
    Params (parsed body): #{inspect(params, pretty: true)}
    """)

    # Extract PayPal-specific headers for verification
    paypal_auth_algo = get_header_value(conn.req_headers, "paypal-auth-algo")
    paypal_cert_url = get_header_value(conn.req_headers, "paypal-cert-url")
    paypal_transmission_id = get_header_value(conn.req_headers, "paypal-transmission-id")
    paypal_transmission_sig = get_header_value(conn.req_headers, "paypal-transmission-sig")
    paypal_transmission_time = get_header_value(conn.req_headers, "paypal-transmission-time")

    Logger.info("""
    🔎 PayPal Verification Headers:
    PAYPAL-AUTH-ALGO: #{inspect(paypal_auth_algo)}
    PAYPAL-CERT-URL: #{inspect(paypal_cert_url)}
    PAYPAL-TRANSMISSION-ID: #{inspect(paypal_transmission_id)}
    PAYPAL-TRANSMISSION-SIG: #{inspect(paypal_transmission_sig)}
    PAYPAL-TRANSMISSION-TIME: #{inspect(paypal_transmission_time)}
    """)

    # --- SIGNATURE VERIFICATION LOGIC WILL GO HERE ---
    # TODO: Construct the signature base string:
    # transmission_id | transmission_time | webhook_id | CRC32 of raw_body
    # TODO: Fetch certificate using paypal_cert_url (PaypalCertificateManager)
    # TODO: Verify signature using :public_key.verify/4 or similar

    # --- TEMPORARY TEST CODE for Certificate Manager (can be removed/adapted later) ---
    case paypal_cert_url do
      cert_url when is_binary(cert_url) ->
        Logger.info("ℹ️ Attempting to get certificate using PAYPAL-CERT-URL: #{cert_url}")

        case Partners.Services.PaypalCertificateManager.get_certificate(cert_url) do
          {:ok, _pem_string} ->
            Logger.info(
              "📄✅ Successfully fetched/retrieved certificate using PaypalCertificateManager for URL: #{cert_url}"
            )

          {:error, reason} ->
            Logger.error(
              "📄❌ Error from PaypalCertificateManager for URL #{cert_url}: #{inspect(reason)}"
            )
        end

      nil ->
        Logger.warning("⚠️ PAYPAL-CERT-URL header not found in webhook request.")
    end

    # --- END OF TEMPORARY TEST CODE ---

    event_type = params["event_type"]
    resource = params["resource"]
    user_id = extract_user_id_from_resource(resource)

    if user_id && event_type do
      case Paypal.process_webhook_event(event_type, resource, user_id) do
        {:ok, subscription_state} ->
          broadcast_subscription_update(user_id, subscription_state)

        {:error, reason} ->
          Logger.error("Error processing PayPal webhook event: #{inspect(reason)}")

          broadcast_subscription_error(
            user_id,
            "Error processing webhook event: #{inspect(reason)}"
          )
      end
    else
      Logger.warning(
        "Missing user_id or event_type in PayPal webhook. Params: #{inspect(params)}"
      )
    end

    send_resp(conn, 200, "OK")
  end

  # Helper to extract a specific header value
  defp get_header_value(headers, header_name) do
    Enum.find_value(headers, fn {name, value} ->
      if String.downcase(name) == String.downcase(header_name), do: value, else: nil
    end)
  end

  # Extract user_id from resource data (adapt based on your PayPal payload structure)
  defp extract_user_id_from_resource(resource) when is_map(resource) do
    # Try different paths where user_id might be stored
    cond do
      # Check custom_id in the subscription object (common for subscription events)
      resource["custom_id"] ->
        resource["custom_id"]

      # Check for subscription object
      resource["subscription"] && resource["subscription"]["custom_id"] ->
        resource["subscription"]["custom_id"]

      # Additional checks as needed for different event types

      true ->
        nil
    end
  end

  defp extract_user_id_from_resource(_), do: nil

  # Broadcast a subscription update event
  defp broadcast_subscription_update(user_id, subscription_state) do
    topic = "paypal_subscription:#{user_id}"

    message = %{
      event: "subscription_updated",
      subscription_state: subscription_state
    }

    Logger.info("Broadcasting subscription update to #{topic}: #{inspect(message)}")
    Phoenix.PubSub.broadcast(Partners.PubSub, topic, message)
  end

  # Broadcast a subscription error event
  defp broadcast_subscription_error(user_id, error_message) do
    topic = "paypal_subscription:#{user_id}"

    message = %{
      event: "subscription_error",
      error: error_message
    }

    Logger.error("Broadcasting subscription error to #{topic}: #{inspect(message)}")
    Phoenix.PubSub.broadcast(Partners.PubSub, topic, message)
  end
end
