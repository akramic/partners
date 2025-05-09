defmodule PartnersWeb.SubscriptionLive do
  @moduledoc """
  LiveView for managing PayPal subscription flows and state.

  ## Architecture

  This LiveView uses Phoenix.LiveView actions to manage different views of the subscription
  process while maintaining state in a single live socket connection. Instead of loading
  new pages for each state, we use `live_action` to switch views while preserving all
  socket assigns and the PubSub subscription.

  ### Live Actions

  * `:index` - Display available subscription plans
  * `:new` - Show subscription confirmation page
  * `:success` - Show current subscription status
  * `:cancel` - Display cancellation confirmation

  The LiveView maintains state through actions by:
  1. Using `handle_params` to update the current action without a full reload
  2. Using `push_patch` for navigation to preserve the socket connection
  3. Keeping subscription state in socket assigns across view changes
  4. Maintaining a persistent PubSub subscription for real-time updates

  For example, when a subscription state changes:
  ```elixir
  # Updates state and changes view without disconnecting
  socket
  |> assign(:subscription_status, :active)
  |> push_patch(to: ~p"/subscriptions/success")
  ```

  ## Subscription Flow

  1. User views subscription plans on the index page
  2. User clicks "Select Plan" to start subscription process (`push_patch` to :new)
  3. User confirms subscription on the new subscription page
  4. System sets state to `:pending` and redirects to success page (`push_patch` to :success)
  5. PayPal webhook updates trigger state changes via PubSub messages
  6. UI updates automatically to reflect current subscription state (maintaining socket)

  ## Subscription States

  * `:pending` - Initial state when subscription is being processed by PayPal
  * `:active` - Subscription is successfully activated and user has full access
  * `:cancelled` - Subscription was cancelled by user or due to payment issues
  * `:failed` - Subscription activation failed (e.g., payment declined)

  ## PubSub Messages

  This LiveView subscribes to `paypal_subscription:{user_id}` and handles:

  1. Subscription Updates:
  ```elixir
  Phoenix.PubSub.broadcast(Partners.PubSub, "paypal_subscription:user123", %{
    event: "subscription_updated",
    subscription_state: :active  # or :pending, :cancelled, :failed
  })
  ```

  2. Subscription Errors:
  ```elixir
  Phoenix.PubSub.broadcast(Partners.PubSub, "paypal_subscription:user123", %{
    event: "subscription_error",
    error: "Payment validation failed"
  })
  ```

  ## Usage

  Add this LiveView to your router:

  ```elixir
  live "/subscriptions", SubscriptionLive, :index
  live "/subscriptions/new", SubscriptionLive, :new
  live "/subscriptions/success", SubscriptionLive, :success
  live "/subscriptions/cancel", SubscriptionLive, :cancel
  ```

  The LiveView will automatically handle subscription state changes and update the UI
  accordingly. Error messages are displayed to users when problems occur, and users
  can retry failed subscriptions or return to the plans page at any time.

  ## TODO: Production Hardening

  The following areas need to be addressed before production deployment:

  ### State Management & Persistence
  * Add database-backed subscription storage
  * Persist subscription attempts and their states
  * Make PayPal subscription IDs queryable outside LiveView
  * Handle browser close/reopen during subscription flow

  ### Security & Authentication
  * Replace temporary user ID with proper authentication
  * Add webhook payload validation
  * Validate subscription events against authenticated user
  * Add rate limiting for subscription attempts

  ### Error Handling
  * Implement PayPal timeout handling
  * Handle network failures during PayPal redirect
  * Add retry mechanism for failed webhook deliveries
  * Handle duplicate webhook events
  * Add timeout handling for stuck pending states

  ### Race Conditions
  * Track multiple subscription attempts per user
  * Match webhook events to specific subscription attempts
  * Validate subscription_status matches current attempt
  * Handle concurrent subscription updates

  ### User Experience Improvements
  * Add loading states during PayPal redirect
  * Implement subscription attempt recovery
  * Add subscription history view
  * Handle subscription upgrades/downgrades
  * Add progress tracking for long-running operations
  """

  use PartnersWeb, :live_view
  require Logger

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
     |> assign(:subscription_id, nil)}
  end

  @doc """
  Handles live action changes without full page reloads.

  This callback is crucial for maintaining state while changing views. It's triggered
  by `push_patch` navigations and updates the current view without disconnecting
  the socket or losing subscription state.
  """
  @impl true
  def handle_params(_params, _url, socket) do
    action = socket.assigns.live_action || :index

    new_assigns = %{live_action: action, page_title: page_title(action)}

    socket =
      if action == :start_trial and socket.assigns.subscription_status == nil do
        # Get the plan_id from the Paypal service
        trial_plan_id = Partners.Services.Paypal.plan_id()
        send(self(), {:initiate_trial_subscription, trial_plan_id})
        socket
      else
        socket
      end

    updated_assigns =
      if action == :success and is_nil(socket.assigns.subscription_status) do
        Map.put(new_assigns, :subscription_status, :pending)
      else
        new_assigns
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
        <%= if @approval_url do %>
          <div class="alert alert-info mb-4">
            <p>Your free trial is ready! Click below to confirm with PayPal.</p>
          </div>
          <a href={@approval_url} class="btn btn-primary mt-2">
            Proceed to PayPal to Start Trial
          </a>
        <% else %>
          <div class="alert alert-info">
            <p>
              <span class="loading loading-spinner loading-sm"></span>
              We're preparing your free trial. This should only take a moment...
            </p>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  @doc """
  Handles PubSub subscription messages and updates the LiveView state.

  This callback receives PayPal webhook events via PubSub and updates the subscription
  state without requiring a page reload. It maintains the socket connection while
  updating the view and state, ensuring a smooth user experience during state transitions.

  The live_action is set to :success to show the updated state, but the socket
  connection and all assigns are preserved.
  """
  @impl true
  def handle_info(message, socket) do
    user_id = socket.assigns.current_scope.user.id
    Logger.info("🔔 LiveView received message for user #{user_id}: #{inspect(message)}")

    case message do
      # Handle PayPal subscription state updates
      %{event: "subscription_updated", subscription_state: state} ->
        Logger.info("Updating subscription state to: #{state}")

        {:noreply,
         socket
         |> assign(:subscription_status, state)
         |> assign(:live_action, :success)}

      # Handle PayPal subscription errors
      %{event: "subscription_error", error: error_message} ->
        Logger.error("Subscription error: #{error_message}")

        {:noreply,
         socket
         |> assign(:subscription_status, :failed)
         |> assign(:error_message, error_message)
         |> assign(:live_action, :success)}

      {:initiate_trial_subscription, plan_id} ->
        Logger.info("Initiating trial subscription with plan_id: #{plan_id}")
        user = socket.assigns.current_scope.user

        case Partners.Services.Paypal.create_subscription(user.id, plan_id) do
          {:ok, subscription_data} ->
            subscription_id = subscription_data["id"]
            approval_url = Partners.Services.Paypal.extract_approval_url(subscription_data)

            if approval_url do
              {:noreply,
               socket
               |> assign(
                 subscription_status: :pending,
                 subscription_id: subscription_id,
                 approval_url: approval_url,
                 error_message: nil
               )}
            else
              {:noreply,
               socket
               |> assign(
                 subscription_status: :failed,
                 error_message: "Failed to create trial: No approval URL from PayPal.",
                 approval_url: nil,
                 subscription_id: nil
               )}
            end

          {:error, reason} ->
            error_message = extract_error_message(reason)

            {:noreply,
             socket
             |> assign(
               subscription_status: :failed,
               error_message: "Failed to create trial: #{error_message}",
               approval_url: nil,
               subscription_id: nil
             )}
        end

      _ ->
        Logger.warning("Received unknown message format: #{inspect(message)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("retry_trial_creation", _params, socket) do
    trial_plan_id = Partners.Services.Paypal.plan_id()
    send(self(), {:initiate_trial_subscription, trial_plan_id})

    {:noreply,
     socket
     |> assign(
       error_message: nil,
       approval_url: nil,
       subscription_status: nil,
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
