defmodule PartnersWeb.Api.Webhooks.WebhookController do
  @moduledoc """
  Controller for handling external webhook callbacks.
  """
  use PartnersWeb, :controller
  require Logger

  @doc """
  Handle PayPal subscription webhook callbacks.

  This endpoint receives webhook events from PayPal related to subscription
  status changes and other subscription-related events.

  It logs the received parameters for debugging and returns a 200 OK response
  to acknowledge receipt of the webhook.
  """
  def paypal(conn, params) do
    Logger.info("Received PayPal webhook: #{inspect(params)}")

    # Use the PayPal service to properly verify and process the webhook
    case Partners.Services.Paypal.handle_webhook(conn) do
      {:ok, event} ->
        # Successfully processed webhook
        Logger.info("Successfully processed PayPal webhook: #{event["event_type"]}")
        send_resp(conn, 200, "OK")

      {:error, reason} ->
        # Failed to process webhook
        Logger.error("Failed to process PayPal webhook: #{inspect(reason)}")
        # Still return 200 to PayPal
        send_resp(conn, 200, "OK")
    end
  end

  @doc """
  Handle PayPal subscription return URLs.

  This endpoint receives redirect requests from PayPal after a user approves or cancels
  a subscription. The :outcome parameter will be either "success" or "cancel".

  For now, this just logs the parameters and renders a simple response.
  In a full implementation, this would:
  1. For "success": Verify the subscription status with PayPal and update the user's account
  2. For "cancel": Clean up any pending subscription state

  ## Parameters

  - `:outcome` - Either "success" or "cancel"
  - Various query parameters from PayPal containing subscription token and info
  """
  def subscription_return(conn, %{"outcome" => outcome} = params) do
    Logger.info("Received PayPal subscription #{outcome} return: #{inspect(params)}")

    case outcome do
      "success" ->
        # Extract the subscription ID and token from the query params
        subscription_id = params["subscription_id"]
        ba_token = params["ba_token"]

        if subscription_id do
          # Process the successful return
          # Partners.Services.Paypal.process_subscription_return(subscription_id, ba_token)

          conn
          |> put_flash(
            :info,
            "Your subscription was successfully set up! You now have a 7-day free trial."
          )
          |> redirect(to: "/subscriptions/test")
        else
          conn
          |> put_flash(:error, "Missing subscription information.")
          |> redirect(to: "/subscriptions/test")
        end

      "cancel" ->
        # No processing needed for cancellation, just redirect back
        conn
        |> put_flash(:info, "Subscription setup was cancelled.")
        |> redirect(to: "/subscriptions/test")

      _ ->
        # Handle unexpected outcome param
        conn
        |> put_flash(:error, "Invalid subscription response.")
        |> redirect(to: "/subscriptions/test")
    end
  end
end
