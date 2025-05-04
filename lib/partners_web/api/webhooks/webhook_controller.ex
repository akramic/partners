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

    # Return a 200 OK response to acknowledge receipt of the webhook
    send_resp(conn, 200, "OK")
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
        # In a real implementation, you would verify the subscription and update the user's account
        conn
        |> put_flash(:info, "Your subscription was successfully set up!")
        |> redirect(to: "/")

      "cancel" ->
        # Handle cancellation
        conn
        |> put_flash(:info, "Subscription setup was cancelled.")
        |> redirect(to: "/")

      _ ->
        # Handle unexpected outcome param
        conn
        |> put_flash(:error, "Invalid subscription response.")
        |> redirect(to: "/")
    end
  end
end
