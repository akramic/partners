defmodule PartnersWeb.Subscription.SubscriptionHelpers do
  @moduledoc """
  Manages the PayPal subscription workflow for trial subscriptions.

  This module provides helper functions to handle the entire PayPal subscription lifecycle:

  1. Initiating a subscription through PayPal
  2. Processing subscription state transitions via webhooks
  3. Handling user returns from PayPal (success or cancel flows)
  4. Managing UI states based on subscription status

  ## Workflow Stages:

  * `:start_trial` - Initial subscription page with PayPal button
  * `:paypal_return` - Processing after user approval on PayPal
  * `:subscription_activated` - Successful activation notification
  * `:paypal_cancel` - Handling when a user cancels on PayPal's site

  ## Key Functions:

  * `request_paypal_approval_url/1` - Creates subscription and redirects to PayPal
  * `process_subscription_action/2` - Handles different live_action states
  * `process_subscription_status_update/2` - Processes PayPal webhook events
  * `process_get_subscription_status_after_timeout/2` - Handles checking subscription status after timeout

  The module also implements a timeout mechanism to handle cases where webhooks might be delayed
  or missing. After a configurable period, it will directly check the subscription status via
  the PayPal API to ensure users aren't left in an indeterminate state.

  The module integrates with the LiveView lifecycle, using socket assigns to maintain
  state and ensure a consistent user experience throughout the asynchronous subscription
  activation process.
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

  def process_subscription_action(
        _params,
        %{assigns: %{live_action: :subscription_activated}} = socket
      ) do
    # Log activation details for debugging/auditing
    user_id = socket.assigns.current_scope.user.id
    subscription_id = socket.assigns[:subscription_id]

    Logger.info("""
    🔔 PayPal subscription activated for user #{user_id}:
    subscription_id: #{inspect(subscription_id)}
    subscription_status: :active
    """)

    # Set up the socket with assigns for the activated state
    socket
    |> assign(:page_title, "Subscription Activated")
    |> assign(:subscription_status, :active)
    |> assign(:error_message, nil)
    |> assign(:transferring_to_paypal, false)
  end

  # This action is related to subscription rejection due to events that
  # aren't relevant for initial trial subscription setup
  # def process_subscription_action(
  #       _params,
  #       %{assigns: %{live_action: :subscription_rejected}} = socket
  #     ) do
  #   # Log rejection details for debugging/auditing
  #   user_id = socket.assigns.current_scope.user.id
  #   subscription_id = socket.assigns[:subscription_id]
  #   failure_reason = socket.assigns[:failure_reason] || "Unknown"

  #   Logger.info("""
  #   🔔 PayPal subscription rejected for user #{user_id}:
  #   subscription_id: #{inspect(subscription_id)}
  #   subscription_status: #{inspect(socket.assigns[:subscription_status])}
  #   failure_reason: #{failure_reason}
  #   """)

  #   # Set up the socket with assigns for the rejected state
  #   socket
  #   |> assign(:page_title, "Subscription Rejected")
  #   |> assign(:error_message, nil)
  #   |> assign(:transferring_to_paypal, false)
  # end

  @doc """
  Handles updates to the subscription status based on PayPal webhook events.

  When a subscription is created, it sets up a timeout mechanism to handle cases
  where webhooks might be delayed or missing. After 120 seconds, if no further
  webhook events are received, it will trigger a direct check of the subscription
  status via the PayPal API.
  """
  def process_subscription_status_update(
        %{"event_type" => "BILLING.SUBSCRIPTION.CREATED"} = params,
        socket
      ) do
    subscription_id = get_in(params, ["resource", "id"])
    status = get_in(params, ["resource", "status"])

    Logger.info("🔔 Subscription created with ID: #{subscription_id}, status: #{status}")

    # Set a 120-second timeout to check subscription status if we don't receive events
    Process.send_after(self(), {:check_subscription_status, subscription_id}, 120_000)

    socket
    |> assign(:subscription_status, :approval_pending)
    |> assign(:subscription_details, params["resource"])
  end

  def process_subscription_status_update(
        %{"event_type" => "BILLING.SUBSCRIPTION.ACTIVATED"} = params,
        socket
      ) do
    subscription_id = get_in(params, ["resource", "id"])
    status = get_in(params, ["resource", "status"])

    Logger.info("🔔 Subscription activated with ID: #{subscription_id}, status: #{status}")

    # Update the socket assigns to reflect the active subscription
    socket =
      socket
      |> assign(:subscription_status, :active)
      |> assign(:subscription_details, params["resource"])
      |> assign(:page_title, "Subscription Activated")
      # We need to use push_patch to update the URL and change the live_action
      |> push_patch(to: ~p"/subscriptions/paypal/subscription_activated")

    # This will cause the UI to render the component for the activated state
    socket
  end

  def process_subscription_status_update(
        %{"event_type" => "BILLING.SUBSCRIPTION.CANCELLED"} = params,
        socket
      ) do
    subscription_id = get_in(params, ["resource", "id"])
    status = get_in(params, ["resource", "status"])
    reason = get_in(params, ["resource", "reason"]) || "Not specified"

    Logger.info(
      "🔔 Subscription cancelled with ID: #{subscription_id}, status: #{status}, reason: #{reason}"
    )

    socket
    |> assign(:subscription_status, :cancelled)
    |> assign(:subscription_details, params["resource"])
    |> assign(:cancellation_reason, reason)
  end

  def process_subscription_status_update(
        %{"event_type" => "BILLING.SUBSCRIPTION.PAYMENT.FAILED"} = params,
        socket
      ) do
    subscription_id = get_in(params, ["resource", "id"])
    status = get_in(params, ["resource", "status"])
    reason = get_in(params, ["resource", "last_failed_payment", "reason"]) || "Not specified"

    Logger.info("""
    🔔 Subscription payment failed with ID: #{subscription_id}, status: #{status}
    Failed reason: #{reason}
    """)

    socket
    |> assign(:subscription_status, :payment_failed)
    |> assign(:subscription_details, params["resource"])
    |> assign(:failure_reason, reason)
    |> push_patch(to: ~p"/subscriptions/paypal/subscription_rejected")
  end

  # This event is not relevant for initial trial subscription setup as it requires
  # an existing billing agreement which only exists after successful activation
  # def process_subscription_status_update(
  #       %{"event_type" => "PAYMENT.SALE.DENIED"} = params,
  #       socket
  #     ) do
  #   subscription_id = get_in(params, ["resource", "billing_agreement_id"])
  #   transaction_id = get_in(params, ["resource", "id"])
  #   reason = get_in(params, ["resource", "reason_code"]) || "Not specified"

  #   Logger.info("""
  #   🔔 Payment denied for subscription ID: #{subscription_id}, transaction ID: #{transaction_id}
  #   Denial reason: #{reason}
  #   """)

  #   socket
  #   |> assign(:subscription_status, :payment_denied)
  #   |> assign(:subscription_details, params["resource"])
  #   |> assign(:transaction_id, transaction_id)
  #   |> assign(:failure_reason, reason)
  #   |> push_patch(to: ~p"/subscriptions/paypal/subscription_rejected")
  # end

  # This event is not relevant for initial trial subscription setup as it relates
  # to disputes on processed payments which can't happen during trial setup
  # def process_subscription_status_update(
  #       %{"event_type" => "RISK.DISPUTE.CREATED"} = params,
  #       socket
  #     ) do
  #   subscription_id =
  #     get_in(params, ["resource", "disputed_transactions", Access.at(0), "billing_agreement_id"])

  #   dispute_id = get_in(params, ["resource", "dispute_id"])
  #   reason = get_in(params, ["resource", "reason"]) || "Not specified"

  #   Logger.info("""
  #   🔔 Risk dispute created for subscription related transaction
  #   Dispute ID: #{dispute_id}
  #   Subscription ID: #{subscription_id}
  #   Dispute reason: #{reason}
  #   """)

  #   socket
  #   |> assign(:subscription_status, :dispute_created)
  #   |> assign(:subscription_details, params["resource"])
  #   |> assign(:dispute_id, dispute_id)
  #   |> assign(:failure_reason, reason)
  #   |> push_patch(to: ~p"/subscriptions/paypal/subscription_rejected")
  # end

  def process_subscription_status_update(params, socket) do
    Logger.info(
      "🔔 Subscription status update received that is not required to be handled by this module: #{inspect(params)}"
    )

    socket
  end

  @doc """
  Handles checking subscription status after the timeout period.

  This function is called after the 120-second timeout following subscription creation
  if no webhook events have updated the subscription status. It directly queries the
  PayPal API to determine the current state of the subscription and updates the UI accordingly.

  It addresses edge cases where webhooks might be delayed, dropped, or not received,
  ensuring users don't get stuck in the approval pending state.
  """
  def process_get_subscription_status_after_timeout(subscription_id, socket) do
    Logger.info("🔔 Checking subscription status after timeout: #{subscription_id}")

    # Only proceed if we're still in approval_pending state
    if socket.assigns.subscription_status == :approval_pending do
      case Partners.Services.Paypal.get_subscription_details(subscription_id) do
        {:ok, subscription_data} ->
          status = Map.get(subscription_data, "status", "UNKNOWN")
          Logger.info("🔔 Retrieved subscription status after timeout: #{status}")

          socket =
            case status do
              "ACTIVE" ->
                # Subscription is active, transition to active state
                socket
                |> assign(:subscription_status, :active)
                |> assign(:subscription_details, subscription_data)
                |> assign(:page_title, "Subscription Activated")
                # Update URL and change live_action
                |> push_patch(to: ~p"/subscriptions/paypal/subscription_activated")

              _ ->
                # Any other status (APPROVAL_PENDING, CANCELLED, etc.)
                # Return to start trial page with flash message
                socket
                |> put_flash(
                  :info,
                  "Sorry, we did not receive any confirmation from PayPal. Please try again."
                )
                |> assign(:subscription_status, nil)
                |> push_patch(to: ~p"/subscriptions/start_trial")
            end

          {:noreply, socket}

        {:error, reason} ->
          # Error retrieving subscription details
          Logger.error("❌ Error checking subscription status: #{inspect(reason)}")

          # Return to start trial with error flash
          socket =
            socket
            |> put_flash(:error, "Failed to verify subscription status. Please try again.")
            |> assign(:subscription_status, nil)
            |> push_patch(to: ~p"/subscriptions/start_trial")

          {:noreply, socket}
      end
    else
      # We've already received an update, no need to do anything
      {:noreply, socket}
    end
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
