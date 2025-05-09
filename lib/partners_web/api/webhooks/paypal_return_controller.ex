defmodule PartnersWeb.Api.Webhooks.PaypalReturnController do
  @moduledoc """
  Controller for handling PayPal subscription return and cancel URLs.

  This controller handles the user's return to the application after
  completing or canceling the PayPal subscription process.
  """
  use PartnersWeb, :controller
  require Logger

  @doc """
  Handle the return from a successful PayPal subscription authorization.

  Redirects users to the subscription success page after they've approved
  the subscription on PayPal's site.
  """
  def return(conn, params) do
    Logger.info("PayPal return with params: #{inspect(params)}")

    # Extract subscription_id and token from PayPal params if available
    subscription_id = Map.get(params, "subscription_id")
    token = Map.get(params, "token")

    # Store these details in the session if needed
    conn =
      if subscription_id,
        do: put_session(conn, :paypal_subscription_id, subscription_id),
        else: conn

    conn = if token, do: put_session(conn, :paypal_token, token), else: conn

    # Redirect to the success page
    redirect(conn, to: ~p"/subscriptions/success")
  end

  @doc """
  Handle the return from a canceled PayPal subscription process.

  Redirects users to the subscription cancel page after they've canceled
  the subscription process on PayPal's site.
  """
  def cancel(conn, params) do
    Logger.info("PayPal cancel with params: #{inspect(params)}")

    # Redirect to the cancel page
    redirect(conn, to: ~p"/subscriptions/cancel")
  end
end
