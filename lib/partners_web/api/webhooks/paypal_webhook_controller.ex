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

  @doc """
  Handle PayPal subscription webhook callbacks.

  Processes incoming webhook notifications from PayPal by:
  1. Reading the raw request body
  2. Processing through Partners.Services.Paypal.process_webhook
  3. Broadcasting to appropriate PubSub channels

  Always returns 200 OK (PayPal best practice) but logs any processing errors.
  """
  def paypal(conn, params) do
    # Log initial webhook receipt
    Logger.info("""
    🔔 WEBHOOK: Received PayPal webhook
    Headers: #{inspect(conn.req_headers, pretty: true)}
    Params: #{inspect(params, pretty: true)}
    """)

    # --- TEMPORARY TEST CODE for Certificate Manager ---
    paypal_cert_url_header =
      Enum.find(conn.req_headers, fn {name, _value} ->
        String.downcase(name) == "paypal-cert-url"
      end)

    case paypal_cert_url_header do
      {_name, cert_url} ->
        Logger.info("ℹ️ Found PAYPAL-CERT-URL header: #{cert_url}")

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

    # Extract event type and resource from params
    event_type = params["event_type"]
    resource = params["resource"]

    # Extract user_id from custom_id in the resource data
    user_id = extract_user_id_from_resource(resource)

    if user_id && event_type do
      # Process the webhook event
      case Partners.Services.Paypal.process_webhook_event(event_type, resource, user_id) do
        {:ok, subscription_state} ->
          # Broadcast to the user's subscription topic
          broadcast_subscription_update(user_id, subscription_state)

        {:error, reason} ->
          # Log the error and optionally broadcast error event
          Logger.error("Error processing PayPal webhook: #{inspect(reason)}")
          broadcast_subscription_error(user_id, "Error processing webhook: #{inspect(reason)}")
      end
    else
      Logger.warning("Missing user_id or event_type in PayPal webhook")
    end

    # Always respond with 200 OK to PayPal (best practice)
    send_resp(conn, 200, "OK")
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
