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

    # Read and decode the raw body
    {:ok, body, _conn} = Plug.Conn.read_body(conn)

    case Jason.decode(body) do
      {:ok, webhook_data} ->
        # Extract subscription and profile information
        subscription_id = webhook_data["resource"]["id"]
        # Assuming we set this during subscription creation
        profile_id = webhook_data["resource"]["custom_id"]
        event_type = webhook_data["event_type"]

        # Create event data
        event_data = %{
          event_type: event_type,
          subscription_id: subscription_id,
          status: webhook_data["resource"]["status"],
          timestamp: webhook_data["create_time"],
          raw_data: webhook_data
        }

        # Broadcast to profile-specific topic
        if profile_id do
          Logger.info("Broadcasting to profile topic: subscription:#{profile_id}")

          Phoenix.PubSub.broadcast(
            Partners.PubSub,
            "subscription:#{profile_id}",
            {:subscription_updated, event_data}
          )
        end

        # Broadcast to global subscriptions topic
        Logger.info("Broadcasting to global subscriptions topic")

        Phoenix.PubSub.broadcast(
          Partners.PubSub,
          "subscriptions",
          {:subscription_event, event_data}
        )

        send_resp(conn, 200, "OK")

      {:error, error} ->
        Logger.error("Failed to decode webhook payload: #{inspect(error)}")
        # Still return 200 to PayPal
        send_resp(conn, 200, "OK")
    end
  end

  @doc """
  Handle PayPal subscription return URLs.

  This endpoint receives redirect requests from PayPal after a user approves or cancels
  a subscription. The :action parameter will be either "success" or "cancel".

  For successful subscriptions:
  1. Retrieves subscription details from query parameters
  2. Broadcasts success event via PubSub
  3. Redirects to appropriate success page

  For cancelled subscriptions:
  1. Broadcasts cancellation event via PubSub
  2. Redirects to cancellation page
  """
  def subscription_return(conn, %{"action" => action} = params) do
    Logger.info("Received PayPal subscription #{action} return: #{inspect(params)}")

    case action do
      "success" ->
        subscription_id = params["subscription_id"]
        # Added during subscription creation
        profile_id = params["profile_id"]

        if subscription_id do
          # Broadcast successful subscription event
          event_data = %{
            event_type: "SUBSCRIPTION.APPROVED",
            subscription_id: subscription_id,
            status: "APPROVAL_PENDING",
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          }

          # Broadcast to both topics
          if profile_id do
            Phoenix.PubSub.broadcast(
              Partners.PubSub,
              "subscription:#{profile_id}",
              {:subscription_updated, event_data}
            )
          end

          Phoenix.PubSub.broadcast(
            Partners.PubSub,
            "subscriptions",
            {:subscription_event, event_data}
          )

          conn
          |> put_flash(
            :info,
            "Subscription successfully set up! You now have a 7-day free trial."
          )
          |> redirect(to: ~p"/subscriptions/success")
        else
          conn
          |> put_flash(:error, "Missing subscription information.")
          |> redirect(to: ~p"/subscriptions")
        end

      "cancel" ->
        profile_id = params["profile_id"]

        # Broadcast cancellation event
        event_data = %{
          event_type: "SUBSCRIPTION.CANCELLED_BY_USER",
          status: "CANCELLED",
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        }

        # Broadcast to both topics
        if profile_id do
          Phoenix.PubSub.broadcast(
            Partners.PubSub,
            "subscription:#{profile_id}",
            {:subscription_updated, event_data}
          )
        end

        Phoenix.PubSub.broadcast(
          Partners.PubSub,
          "subscriptions",
          {:subscription_event, event_data}
        )

        conn
        |> put_flash(:info, "Subscription setup was cancelled.")
        |> redirect(to: ~p"/subscriptions/cancel")

      _ ->
        conn
        |> put_flash(:error, "Invalid subscription response.")
        |> redirect(to: ~p"/subscriptions")
    end
  end
end
