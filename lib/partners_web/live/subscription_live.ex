defmodule PartnersWeb.SubscriptionLive do
  @moduledoc """
  LiveView for managing PayPal subscription trial flows and state.

  ## Architecture

  This LiveView uses Phoenix.LiveView actions to manage different views of the subscription
  process, primarily focusing on a streamlined free trial initiation.

  ### Live Actions

  * `:start_trial` - Page where users initiate the PayPal approval for a free trial.
  * `:success` - Displays the status of the subscription (e.g., pending, active, failed)
    after returning from PayPal or via real-time webhook updates.
  * `:cancel` - Displays a message if the user cancels the PayPal approval process.

  The LiveView maintains state by:
  1. Using `handle_params` to set up the view for the current action.
  2. Using `redirect/2` for external navigation to PayPal.
  3. Using `push_patch` (implicitly via `live_patch` in templates or explicitly in
     `handle_info` for certain PubSub events) to change views (e.g., to `:start_trial`
     on verification failure) or update the current view while preserving the socket.
  4. Keeping subscription-related state in socket assigns (e.g., `subscription_status`,
     `error_message`, `transferring_to_paypal`).
  5. Maintaining a persistent PubSub subscription for real-time updates from webhooks
     processed by `PaypalWebhookController`.

  ## Trial Subscription Flow

  1.  New user registers and is redirected to the `/subscriptions/start_trial` page.
  2.  User is presented with a "Start Trial with PayPal" button.
  3.  User clicks the button; a "Transferring to PayPal..." message is displayed.
      The `handle_event("request_paypal_approval_url", ...)` function sets
      `transferring_to_paypal` to `true` and sends an internal
      `:_process_paypal_trial_creation` message.
  4.  The `handle_info(:_process_paypal_trial_creation, socket)` function calls the
      PayPal API (`Partners.Services.Paypal.create_subscription/2`) to create a trial
      subscription.
  5.  Upon receiving an approval URL from PayPal, the user's browser is redirected to
      PayPal via `redirect(socket, external: approval_url)`.
  6.  User approves (or cancels) the subscription on PayPal.
  7.  PayPal redirects the user back to the application's return URLs
      (`/paypal/return` or `/paypal/cancel`).
  8.  The `PaypalReturnController` handles these returns, typically redirecting the user
      to the `/subscriptions/success` (or `/subscriptions/cancel`) LiveView action.
  9.  The `SubscriptionLive` view (e.g., on `:success` action) displays the current
      subscription status, initially often `:pending`.
  10. Asynchronous PayPal webhook events (e.g., `BILLING.SUBSCRIPTION.ACTIVATED`,
      `BILLING.SUBSCRIPTION.CANCELLED`, or events leading to verification failure)
      are received by `PaypalWebhookController`.
  11. The webhook controller broadcasts PubSub messages.
  12. `SubscriptionLive`'s `handle_info/2` function processes these PubSub messages to
      update the subscription status in real-time (e.g., from `:pending` to `:active`
      on the `:success` page) or to display flash messages and redirect the user
      (e.g., to `:start_trial` with an error flash on verification failure).

  ## Subscription States (primarily for the `:success` view)

  * `:pending` - Initial state after user approval on PayPal, awaiting final activation.
  * `:active` - Subscription is successfully activated.
  * `:failed` - Subscription activation failed (either due to API errors during creation
    or error events from webhooks).
  * `:cancelled` - User cancelled on PayPal, or subscription was cancelled later.

  ## PubSub Messages

  Subscribes to `paypal_subscription:{user_id}` and handles:
  * `%{event: "subscription_updated", subscription_state: state}`: Updates the
    `subscription_status` and ensures the view is appropriate (typically `:success`).
  * `%{event: "subscription_error", error: error_message}`: Sets `subscription_status`
    to `:failed`, stores the `error_message`, and navigates to the `:success` action
    to display the error state.
  * `%{event: "subscription_verification_failed", details: %{message: flash_message}}`:
    This is a critical update. When a webhook verification fails and the fallback also
    doesn't confirm an active subscription, this event is received. The LiveView
    displays the `flash_message` (e.g., "We're having trouble confirming the setup
    of your Paypal trial subscription. Please try again...") and uses `push_patch`
    to redirect the user back to the `/subscriptions/start_trial` page, allowing them
    to retry or contact support.

  ## Usage (Router Examples)

  ```elixir
  # In your router.ex
  scope "/", PartnersWeb do
    pipe_through [:browser, :require_authenticated_user] # Ensure user is authenticated

    live "/subscriptions/start_trial", SubscriptionLive, :start_trial
    live "/subscriptions/success", SubscriptionLive, :success
    live "/subscriptions/cancel", SubscriptionLive, :cancel
  end
  ```

  ## TODO: Production Hardening

  The following areas should be reviewed or implemented for production:

  ### State Management & Persistence
  * Ensure robust database-backed storage for subscription details (ID, status, PayPal `payer_id`, trial period dates).
  * Persist subscription attempts and their states, especially if more complex flows are added later.
  * Handle cases where a user might close the browser after PayPal approval but before returning to the app or before the webhook confirms activation. Ensure the system can reconcile state.

  ### Security & Authentication
  * Verify that user authentication and authorization are secure throughout the flow.
  * Ensure robust PayPal webhook payload validation (signature verification).
  * Implement trial abuse prevention (e.g., by checking the PayPal `payer_id` against previously used IDs for trials). This is a high-priority pending task.
  * Consider rate limiting for trial creation attempts if abuse is detected.

  ### Error Handling
  * Comprehensive handling for PayPal API errors, network failures during redirects or API calls.
  * Robust retry mechanisms or clear user guidance for transient failures.
  * Ensure webhook delivery failures are handled (e.g., PayPal's retry mechanism, monitoring).
  * Idempotency for webhook event processing.
  * Timeout handling for states that might get stuck (e.g., a subscription remaining `:pending` indefinitely).

  ### Race Conditions
  * Ensure that concurrent updates or webhook events for the same subscription/user are handled correctly to prevent inconsistent states.
  * Validate that webhook events correspond to legitimate and current subscription attempts/records.

  ### User Experience Improvements
  * Refine loading/spinner states for all asynchronous operations.
  * Clear feedback for all outcomes (success, failure, cancellation).
  * If applicable in the future: subscription management (view history, cancel active subscription, update payment).
  * Progress tracking if any part of the flow becomes longer.
  """

  use PartnersWeb, :live_view
  require Logger

  @doc """
  Mounts the LiveView, subscribes to user-specific PayPal PubSub events,
  and initializes default socket assigns.

  Initial assigns include:
  - `page_title`: Default page title.
  - `subscription_status`: Initially `nil`.
  - `error_message`: Initially `nil`.
  - `approval_url`: Initially `nil` (used internally before redirect).
  - `subscription_id`: Initially `nil` (PayPal subscription ID).
  - `transferring_to_paypal`: Boolean flag for UI, initially `false`.
  """
  @impl true
  def mount(_params, _session, socket) do
    # Use the real user from the current scope
    user = socket.assigns.current_scope.user
    user_id = user.id

    Logger.info("Subscription LiveView mounted with user_id: #{user_id}")

    if connected?(socket) do
      subscription_topic = "paypal_subscription:#{user_id}"
      Logger.info("Subscribing to PayPal subscription topic: #{subscription_topic}")
      :ok = Phoenix.PubSub.subscribe(Partners.PubSub, subscription_topic)
      Logger.info("Successfully subscribed to PayPal subscription topic")
    else
      Logger.info("Socket not connected yet, skipping PubSub subscription")
    end

    {:ok,
     socket
     |> assign(:page_title, "Subscription")
     |> assign(:subscription_status, nil)
     |> assign(:error_message, nil)
     |> assign(:approval_url, nil)
     |> assign(:subscription_id, nil)
     # Added
     |> assign(:transferring_to_paypal, false)}
  end

  @doc """
  Handles live action changes, typically when navigating to `:start_trial`,
  `:success`, or `:cancel` actions.

  It updates the `page_title` based on the action. For the `:start_trial`
  action, it resets UI-related assigns like `transferring_to_paypal`,
  `error_message`, and `subscription_status` to ensure a clean state.
  For the `:success` action, it may set a default `subscription_status`
  of `:pending` if not already set (e.g., on initial load after redirect
  from PayPal return URL before any webhooks).
  """
  @impl true
  def handle_params(_params, _url, socket) do
    # This is the new action from the URL
    action = socket.assigns.live_action

    current_assigns = %{
      live_action: action,
      page_title: page_title(action)
    }

    updated_assigns =
      case action do
        :start_trial ->
          Map.merge(current_assigns, %{
            transferring_to_paypal: false,
            approval_url: nil,
            error_message: nil,
            # Reset state for start_trial page
            subscription_status: nil
          })

        :success ->
          if is_nil(socket.assigns.subscription_status) do
            Map.put(current_assigns, :subscription_status, :pending)
          else
            current_assigns
          end

        _ ->
          current_assigns
      end

    {:noreply, assign(socket, updated_assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <PartnersWeb.Layouts.app current_scope={@current_scope} flash={@flash}>
      <div class="max-w-2xl mx-auto py-8">
        {render_content(assigns)}
      </div>
    </PartnersWeb.Layouts.app>
    """
  end

  # Individual templates for each subscription state
  defp render_content(%{live_action: :success} = assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-bold mb-4">Subscription Status</h1>
      <div class={[
        "alert mb-4",
        @subscription_status == :active && "alert-success",
        @subscription_status == :pending && "alert-info",
        @subscription_status == :failed && "alert-error",
        @subscription_status == :cancelled && "alert-warning"
      ]}>
        <p>
          <%= case @subscription_status do %>
            <% :active -> %>
              Your subscription is active! You now have full access.
            <% :pending -> %>
              <span class="loading loading-spinner loading-sm"></span> Processing your subscription...
            <% :failed -> %>
              Subscription activation failed.
            <% :cancelled -> %>
              Your subscription has been cancelled.
            <% _ -> %>
              Unknown status: {@subscription_status}
          <% end %>
        </p>
      </div>

      <%= if @subscription_status == :pending and @approval_url do %>
        <div class="mb-4">
          <p>To complete your subscription, please proceed to PayPal for payment.</p>
          <a href={@approval_url} class="btn btn-primary mt-2">
            Proceed to PayPal
          </a>
        </div>
      <% end %>

      <div class="flex gap-2"></div>
    </div>
    """
  end

  defp render_content(%{live_action: :cancel} = assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-bold mb-4">Subscription Cancelled</h1>
      <div class="alert alert-warning">
        <p>Your subscription process was cancelled.</p>
      </div>
    </div>
    """
  end

  defp render_content(%{live_action: :start_trial} = assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-bold mb-4">Start Your Free Trial</h1>

      <%= if @subscription_status == :failed and @error_message do %>
        <div class="alert alert-error mb-4">
          <p>Oops! Something went wrong: {@error_message}</p>
        </div>
        <button phx-click="retry_trial_creation" class="btn btn-sm btn-primary">
          Try Again
        </button>
      <% else %>
        <%= if @transferring_to_paypal do %>
          <div class="alert alert-info">
            <p>
              <span class="loading loading-spinner loading-sm"></span>
              Transferring you to PayPal. This should only take a moment...
            </p>
          </div>
        <% else %>
          <div class="alert alert-info mb-4">
            <p>Your free trial is one click away! Click below to confirm with PayPal.</p>
          </div>
          <button
            phx-click="request_paypal_approval_url"
            class="mt-2 inline-flex items-center justify-center px-6 py-3 border border-transparent rounded-full shadow-sm text-base font-medium text-[#003087] bg-[#ffc439] hover:bg-[#f5bb00] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#f5bb00]"
          >
            <img src="/images/paypal_logo.svg" alt="PayPal" class="mr-2 h-5 w-auto" />
            <span>Start Trial</span>
          </button>
        <% end %>
      <% end %>
    </div>
    """
  end

  @doc """
  Handles internal messages and PubSub events.

  Clause breakdown:
  - `:_process_paypal_trial_creation`: An internal message sent after the user
    requests to start a trial. This handler makes the asynchronous call to
    `Partners.Services.Paypal.create_subscription/2`. On success, it extracts
    the PayPal approval URL and uses `redirect(socket, external: approval_url)`
    to send the user to PayPal. On failure, it updates the UI with an error
    message and sets `transferring_to_paypal` to `false`.

  - `%{event: "subscription_updated", subscription_state: state}`: Handles PubSub
    messages broadcast by the `PaypalWebhookController` when a subscription's
    state changes (e.g., to `:active`, `:cancelled`). It updates the
    `subscription_status` assign. If the user is currently on the `:start_trial`
    page and a redirect to PayPal is in progress (`transferring_to_paypal` is true),
    it avoids changing `live_action` to prevent disrupting the redirect. Otherwise,
    it typically ensures the `live_action` is `:success` to display the status.

  - `%{event: "subscription_error", error: error_message}`: Handles PubSub messages
    for subscription errors, updating `subscription_status` to `:failed`,
    setting `error_message`, and navigating to the `:success` action to display
    the error state.

  - `%{event: "subscription_verification_failed", details: %{message: flash_message}}`:
    This event is handled to manage cases where the webhook verification fails.
    It logs the error, displays the `flash_message` to the user, and uses
    `push_patch` to navigate the user back to the `:start_trial` action, allowing
    them to retry the subscription process.
  """
  @impl true
  def handle_info(message, socket) do
    # For logging
    user_id = socket.assigns.current_scope.user.id

    case message do
      :_process_paypal_trial_creation ->
        Logger.info("🔔 LiveView: Processing PayPal trial creation for user #{user_id}")
        user = socket.assigns.current_scope.user
        trial_plan_id = Partners.Services.Paypal.plan_id()

        case Partners.Services.Paypal.create_subscription(user.id, trial_plan_id) do
          {:ok, subscription_data} ->
            subscription_id = subscription_data["id"]
            approval_url = Partners.Services.Paypal.extract_approval_url(subscription_data)

            if approval_url do
              Logger.info(
                "🔔 LiveView: Redirecting user #{user_id} to PayPal approval URL (via redirect/2): #{approval_url}"
              )

              socket_with_assigns =
                assign(socket, subscription_id: subscription_id, transferring_to_paypal: true)

              # Correct way to redirect to an external URL
              {:noreply, redirect(socket_with_assigns, external: approval_url)}
            else
              # Error: No approval URL from PayPal
              Logger.error("🔔 LiveView: No approval URL from PayPal for user #{user_id}")

              {:noreply,
               assign(socket,
                 subscription_status: :failed,
                 error_message: "Failed to prepare PayPal: No approval URL received from PayPal.",
                 # Hide spinner, show error
                 transferring_to_paypal: false
               )}
            end

          {:error, reason} ->
            # Error: PayPal API call failed
            error_message = extract_error_message(reason)
            Logger.error("🔔 LiveView: PayPal API error for user #{user_id} - #{error_message}")

            {:noreply,
             assign(socket,
               subscription_status: :failed,
               error_message: "Failed to prepare PayPal: #{error_message}",
               # Hide spinner, show error
               transferring_to_paypal: false
             )}
        end

      %{event: "subscription_updated", subscription_state: state} ->
        Logger.info(
          "🔔 LiveView: PubSub subscription_updated for user #{user_id} to state: #{state}"
        )

        # If we are in the process of redirecting from :start_trial,
        # don't change the live_action prematurely. The redirect and subsequent
        # page load/param handling will set the correct live_action.
        # Only update subscription_status. The redirect should take precedence.
        if socket.assigns.live_action == :start_trial && socket.assigns.transferring_to_paypal do
          {:noreply, assign(socket, subscription_status: state)}
        else
          # Otherwise, it's a normal update, likely on the :success page already,
          # or the redirect from :start_trial has completed/failed and transferring_to_paypal is false.
          {:noreply,
           socket
           |> assign(subscription_status: state, live_action: :success)}
        end

      %{event: "subscription_error", error: error_message} ->
        Logger.error(
          "🔔 LiveView: PubSub subscription_error for user #{user_id}: #{error_message}"
        )

        {:noreply,
         socket
         |> assign(
           subscription_status: :failed,
           error_message: error_message,
           live_action: :success
         )}

      %{
        event: "subscription_verification_failed",
        details: %{reason: reason_from_details, message: flash_message}
      } ->
        Logger.error(
          "🔔 LiveView: PubSub subscription_verification_failed for user #{user_id}. Reason: #{reason_from_details}"
        )

        {:noreply,
         socket
         |> put_flash(:error, flash_message)
         |> push_patch(to: ~p"/subscriptions/start_trial")}

      _ ->
        Logger.warning(
          "🔔 LiveView: Received unknown message for user #{user_id}: #{inspect(message)}"
        )

        {:noreply, socket}
    end
  end

  @doc """
  Handles `phx-click` events from the client.

  Clause breakdown:
  - `"request_paypal_approval_url"`: Triggered by the "Start Trial" button on the
    `:start_trial` page. It sets `transferring_to_paypal` to `true` to display
    a spinner/message, resets relevant assigns (error_message, approval_url,
    subscription_status), and sends an internal `:_process_paypal_trial_creation`
    message to `self()` to initiate the asynchronous PayPal API call.

  - `"retry_trial_creation"`: Triggered by the "Try Again" button on the
    `:start_trial` page, typically shown after a failed trial initiation.
    It resets assigns like `error_message`, `approval_url`, `subscription_status`,
    and `transferring_to_paypal` to `false`, and sets the `page_title`
    appropriately, allowing the user to attempt the trial creation process
    again from a clean state.
  """
  @impl true
  def handle_event("request_paypal_approval_url", _params, socket) do
    # Immediately show spinner and schedule PayPal call
    socket_updated =
      assign(socket,
        transferring_to_paypal: true,
        error_message: nil,
        approval_url: nil,
        # Reset status
        subscription_status: nil
      )

    # Underscore to indicate internal message
    send(self(), :_process_paypal_trial_creation)
    {:noreply, socket_updated}
  end

  # No @doc here as it's consolidated above
  @impl true
  def handle_event("retry_trial_creation", _params, socket) do
    {:noreply,
     socket
     |> assign(
       error_message: nil,
       approval_url: nil,
       subscription_status: nil,
       transferring_to_paypal: false,
       page_title: page_title(:start_trial)
     )}
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

  # Helper functions
  defp page_title(:success), do: "Subscription Status"
  defp page_title(:cancel), do: "Subscription Cancelled"
  # Updated page title
  defp page_title(:start_trial), do: "Start Your Free Trial"
  defp page_title(_), do: "Subscription"
end
