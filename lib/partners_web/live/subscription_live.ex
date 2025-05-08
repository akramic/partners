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
    # Generate temporary user ID for testing
    # Future: This will be replaced with actual user ID from scope
    temp_user_id = "temp_#{:crypto.strong_rand_bytes(8) |> Base.encode16()}"

    Logger.info("Subscription LiveView mounted with temp_user_id: #{temp_user_id}")

    if connected?(socket) do
      subscription_topic = "paypal_subscription:#{temp_user_id}"
      Logger.info("Subscribing to PayPal subscription topic: #{subscription_topic}")
      :ok = Phoenix.PubSub.subscribe(Partners.PubSub, subscription_topic)
      Logger.info("Successfully subscribed to PayPal subscription topic")
    else
      Logger.info("Socket not connected yet, skipping PubSub subscription")
    end

    # Create a temporary user struct for testing
    temp_user = %{
      id: temp_user_id,
      email: "test@example.com",
      confirmed_at: DateTime.utc_now()
    }

    # Set up scope with proper user struct
    {:ok,
     socket
     |> assign(:page_title, "Subscription")
     |> assign(:current_scope, %{
       user: temp_user,
       temp_id: temp_user_id
     })
     |> assign(:subscription_status, nil)
     |> assign(:error_message, nil)}
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

    {:noreply,
     socket
     |> assign(:live_action, action)
     |> assign(:page_title, page_title(action))}
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
  defp render_content(%{live_action: :index} = assigns) do
    ~H"""
    <div class="space-y-8">
      <h1 class="text-2xl font-bold">Subscription Plans</h1>
      <div class="grid gap-6">
        <!-- Show current subscription status -->
        <div :if={@subscription_status} class="alert alert-info">
          <p>Current Status: {@subscription_status}</p>
        </div>

        <.subscription_card />
      </div>
    </div>
    """
  end

  defp render_content(%{live_action: :new} = assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-bold mb-4">Start New Subscription</h1>
      <!-- Future: Will show selected plan details -->
      <button phx-click="create_subscription" class="btn btn-primary">
        Subscribe Now
      </button>
    </div>
    """
  end

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
              Subscription activation failed. Please try again.
            <% :cancelled -> %>
              Your subscription has been cancelled.
            <% _ -> %>
              Unknown status: {@subscription_status}
          <% end %>
        </p>
      </div>

      <div class="flex gap-2">
        <.link patch={~p"/subscriptions"} class="btn btn-sm">
          Return to Plans
        </.link>

        <%= if @subscription_status == :failed do %>
          <.link patch={~p"/subscriptions/new"} class="btn btn-sm btn-primary">
            Try Again
          </.link>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_content(%{live_action: :cancel} = assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-bold mb-4">Subscription Cancelled</h1>
      <div class="alert alert-warning">
        <p>Your subscription process was cancelled.</p>
        <.link patch={~p"/subscriptions"} class="btn btn-sm mt-4">
          Return to Plans
        </.link>
      </div>
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
    user_id = socket.assigns.current_scope.temp_id
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

      _ ->
        Logger.warning("Received unknown message format: #{inspect(message)}")
        {:noreply, socket}
    end
  end

  @doc """
  Handles the initial subscription creation event.

  Uses push_patch for navigation to maintain the LiveView socket connection while
  changing to the success view. This ensures that:
  1. The PubSub subscription remains active
  2. All socket assigns are preserved
  3. The user sees immediate feedback (pending state)
  4. The socket is ready to receive PayPal webhook updates
  """
  @impl true
  def handle_event("create_subscription", _params, socket) do
    # Simulate a subscription creation
    # In real implementation, this would create a PayPal subscription and redirect to PayPal

    # Set the status to pending and redirect to success page
    {:noreply,
     socket
     |> assign(:subscription_status, :pending)
     |> push_patch(to: ~p"/subscriptions/success")}
  end

  # Helper functions
  defp subscription_card(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <h2 class="card-title">Premium Subscription</h2>
        <p>$19.99/month</p>
        <div class="card-actions justify-end">
          <.link patch={~p"/subscriptions/new"} class="btn btn-primary">
            Select Plan
          </.link>
        </div>
      </div>
    </div>
    """
  end

  defp page_title(:index), do: "Subscription Plans"
  defp page_title(:new), do: "New Subscription"
  defp page_title(:success), do: "Subscription Status"
  defp page_title(:cancel), do: "Subscription Cancelled"
  defp page_title(_), do: "Subscription"
end
