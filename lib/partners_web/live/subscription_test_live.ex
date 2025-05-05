defmodule PartnersWeb.SubscriptionTestLive do
  use PartnersWeb, :live_view
  require Logger

  def mount(_params, _session, socket) do
    # Debug: Check if the plan exists and is active
    plan_id = Partners.Services.Paypal.subscription_plan_id_aud()

    plan_status =
      case Partners.Services.Paypal.get_subscription_plan(plan_id) do
        {:ok, plan} -> "ACTIVE: #{plan["status"]}"
        {:error, reason} -> "ERROR: #{inspect(reason)}"
      end

    {:ok,
     socket
     |> assign(:subscription_url, nil)
     |> assign(:profile_id, "test_profile_#{:rand.uniform(1000)}")
     |> assign(:loading, false)
     |> assign(:plan_status, plan_status)
     |> assign(:plan_id, plan_id)
     |> assign(:error, nil)}
  end

  def handle_event("create_subscription", _params, socket) do
    # Set loading state
    socket = assign(socket, loading: true, error: nil)

    # Generate a test profile ID if one doesn't exist
    profile_id = socket.assigns.profile_id

    # Create subscription URL
    case Partners.Services.Paypal.create_subscription_url(profile_id) do
      {:ok, %{subscription_id: subscription_id, approve_url: url}} ->
        # Subscribe to subscription events for this profile
        Phoenix.PubSub.subscribe(Partners.PubSub, "subscription:#{profile_id}")

        {:noreply,
         socket
         |> assign(loading: false)
         |> assign(subscription_url: url)
         |> assign(subscription_id: subscription_id)}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(loading: false)
         |> assign(error: "Failed to create subscription: #{inspect(reason)}")}
    end
  end

  # Handle subscription update events from PubSub
  def handle_info({:subscription_updated, event_data}, socket) do
    {:noreply,
     socket
     |> assign(:last_event, event_data)
     |> assign(:subscription_status, event_data.status)}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-6 bg-white rounded-lg shadow-md">
      <h1 class="text-2xl font-bold mb-4">PayPal Subscription Test</h1>

      <div class="mb-4">
        <p class="text-gray-600 mb-2">
          Test Profile ID: <span class="font-mono">{@profile_id}</span>
        </p>

        <button phx-click="create_subscription" class="btn btn-primary" disabled={@loading}>
          {if @loading, do: "Creating...", else: "Create Test Subscription"}
        </button>
      </div>

      <%= if @error do %>
        <div class="bg-red-100 text-red-700 p-4 rounded mb-4">
          <p>{@error}</p>
        </div>
      <% end %>

      <%= if @subscription_url do %>
        <div class="bg-blue-50 p-4 rounded mb-4">
          <h2 class="text-lg font-semibold mb-2">Subscription Created!</h2>
          <p class="mb-2">Subscription ID: <span class="font-mono">{@subscription_id}</span></p>
          <p class="mb-4">
            Click the button below to continue to PayPal and approve the subscription:
          </p>

          <a href={@subscription_url} target="_blank" class="btn btn-success">
            Continue to PayPal
          </a>
        </div>
      <% end %>

      <%= if assigns[:last_event] do %>
        <div class="mt-6">
          <h2 class="text-lg font-semibold mb-2">Latest Subscription Event</h2>
          <div class="bg-gray-50 p-4 rounded">
            <p>Status: <span class="font-semibold">{@subscription_status}</span></p>
            <p>Event Type: <span class="font-mono text-xs">{@last_event.event_type}</span></p>
            <p>Timestamp: <span class="text-xs">{@last_event.timestamp}</span></p>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
