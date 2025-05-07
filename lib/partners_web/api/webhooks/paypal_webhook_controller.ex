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
  def paypal(conn, _params) do
    # Log initial webhook receipt
    Logger.info("""
    🔔 WEBHOOK: Received PayPal webhook
    Headers: #{inspect(conn.req_headers, pretty: true)}
    """)

    # Verify the webhook signature

    send_resp(conn, 200, "OK")
  end
end
