defmodule PartnersWeb.Subscription.SubscriptionHelpers do
  @moduledoc """
  Helper module containing business logic for PayPal subscription flows.

  This module handles the processing of different subscription actions and states,
  including PayPal API interactions, parameter processing, and state management.

  ## Key Responsibilities

  1. **Processing Different Live Actions**
     - Handles state setup for different phases of subscription flow (start_trial, paypal_return, paypal_cancel)
     - Extracts and processes PayPal URL parameters
     - Sets appropriate socket assigns based on the current subscription state

  2. **PayPal Integration**
     - Creates PayPal subscriptions via the PayPal service module
     - Processes PayPal's response data and extracts URLs, IDs, and tokens
     - Handles error cases during PayPal API calls

  3. **Error Handling**
     - Manages various error scenarios in the subscription process
     - Provides detailed logging for troubleshooting
     - Sets appropriate error states for the UI

  This module is designed to keep the LiveView focused on handling events and rendering,
  while encapsulating all subscription-specific business logic here.
  """

  use PartnersWeb, :live_view
  require Logger

  def request_paypal_approval_url(socket) do
    user = socket.assigns.current_scope.user
    trial_plan_id = Partners.Services.Paypal.plan_id()
    user_id = user.id

    Logger.info("🔔 LiveView: Processing PayPal trial creation for user #{user_id}")

    with {:ok, subscription_data} <-
           Partners.Services.Paypal.create_subscription(user.id, trial_plan_id),
         {:ok, subscription_id} <- extract_subscription_id(subscription_data),
         {:ok, approval_url} <- Partners.Services.Paypal.extract_approval_url(subscription_data) do
      Logger.info(
        "🔔 LiveView: Redirecting user #{user_id} to PayPal approval URL (via redirect/2): #{approval_url}"
      )

      socket_with_assigns = assign(socket, subscription_id: subscription_id)

      # Redirect to external URL
      {:noreply, redirect(socket_with_assigns, external: approval_url)}
    else
      # Handle specific subscription ID errors
      {:error, error_type}
      when error_type in [
             :empty_subscription_id,
             :subscription_id_not_found,
             :invalid_subscription_id_format
           ] ->
        log_error(user_id, "Invalid subscription data", error_type)

        handle_subscription_error(
          socket,
          "Invalid subscription data received.",
          user_id
        )

      # Handle approval URL not found
      {:error, :link_not_found} ->
        log_error(user_id, "No approval URL from PayPal")

        handle_subscription_error(
          socket,
          "No approval URL received from PayPal.",
          user_id
        )

      # Handle any other PayPal API errors
      {:error, reason} ->
        error_message = extract_error_message(reason)
        log_error(user_id, "PayPal API error", error_message)

        handle_subscription_error(
          socket,
          error_message,
          user_id
        )
    end
  end

  def process_subscription_action(_params, %{assigns: %{live_action: :start_trial}} = socket) do
    socket
    |> assign(:page_title, "Start Your Free Trial")
    |> assign(:subscription_status, nil)
    |> assign(:error_message, nil)
    |> assign(:transferring_to_paypal, false)
  end

  def process_subscription_action(params, %{assigns: %{live_action: :paypal_cancel}} = socket) do
    # Log cancel params for debugging
    user_id = socket.assigns.current_scope.user.id
    Logger.info("🔔 PayPal cancel for user #{user_id}: #{inspect(params)}")

    # Extract any relevant parameters
    token = Map.get(params, "token")

    socket
    |> assign(:page_title, "Subscription Cancelled")
    |> assign(:subscription_status, :cancelled)
    |> assign(:error_message, nil)
    |> assign(:transferring_to_paypal, false)
    # Store token if available
    |> assign(:paypal_token, token)
  end

  def process_subscription_action(params, %{assigns: %{live_action: :paypal_return}} = socket) do
    # Extract PayPal data from params
    subscription_id = Map.get(params, "subscription_id")
    token = Map.get(params, "token")
    # Billing agreement token, sometimes provided
    ba_token = Map.get(params, "ba_token")

    # Log the return for debugging/auditing
    user_id = socket.assigns.current_scope.user.id

    Logger.info("""
    🔔 PayPal return for user #{user_id}:
    subscription_id: #{inspect(subscription_id)}
    token: #{inspect(token)}
    ba_token: #{inspect(ba_token)}
    all params: #{inspect(params)}
    """)

    # Set subscription ID if provided by PayPal
    socket =
      if subscription_id, do: assign(socket, :subscription_id, subscription_id), else: socket

    # Store additional PayPal data that might be needed later
    socket =
      socket
      |> assign(:page_title, "Subscription Processing")
      |> assign(:subscription_status, :pending)
      |> assign(:error_message, nil)
      |> assign(:transferring_to_paypal, false)
      |> assign(:paypal_token, token)
      |> assign(:paypal_ba_token, ba_token)

    # You could also consider making an API call to PayPal here to get
    # subscription details, although typically this would be unnecessary
    # since webhooks will provide this information

    socket
  end

  # Helper function to handle subscription errors and assign error state to socket
  defp handle_subscription_error(socket, error_message, user_id) do
    Logger.error("🔔 LiveView: Failed to prepare PayPal for user #{user_id}: #{error_message}")

    {:noreply,
     assign(socket,
       subscription_status: :failed,
       error_message: "Failed to prepare PayPal: #{error_message}",
       transferring_to_paypal: false
     )}
  end

  # Helper function to log errors with consistent format
  defp log_error(user_id, message, details \\ nil) do
    details_str = if details, do: " - #{inspect(details)}", else: ""
    Logger.error("🔔 LiveView: #{message} for user #{user_id}#{details_str}")
  end

  defp extract_subscription_id(subscription_data) when is_map(subscription_data) do
    case Map.fetch(subscription_data, "id") do
      {:ok, id} when is_binary(id) and id != "" -> {:ok, id}
      {:ok, ""} -> {:error, :empty_subscription_id}
      :error -> {:error, :subscription_id_not_found}
      _ -> {:error, :invalid_subscription_id_format}
    end
  end

  # Helper to extract a friendly error message from PayPal API error responses
  defp extract_error_message(error) when is_map(error) do
    cond do
      # Try to get detailed error message from PayPal response
      get_in(error, ["name"]) ->
        "#{get_in(error, ["name"])}: #{get_in(error, ["message"])}"

      # Fallback for other error structures
      true ->
        inspect(error)
    end
  end

  defp extract_error_message(error), do: inspect(error)
end
