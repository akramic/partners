defmodule PartnersWeb.SubscriptionLive do
  @moduledoc """
  LiveView for managing PayPal subscription trial flows and state.

  """

  use PartnersWeb, :live_view
  require Logger

  alias PartnersWeb.Subscription.SubscriptionHelpers

  @doc """
  Mounts the LiveView, subscribes to user-specific PayPal PubSub events,
  and initializes default socket assigns.

  """
  @impl true
  def mount(_params, _session, socket) do
    # Use the real user from the current scope
    Logger.info("Mounting Subscription LiveView live_action: #{socket.assigns.live_action}")
    user = socket.assigns.current_scope.user
    user_id = user.id

    Logger.info("Subscription LiveView mounted with user_id: #{user_id}")
    Logger.info("Live action: #{socket.assigns.live_action}")

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
     |> assign(:page_title, "Subscription setup")
     |> assign(:subscription_status, nil)
     |> assign(:error_message, nil)
     |> assign(:approval_url, nil)
     |> assign(:subscription_id, nil)
     # Added
     |> assign(:transferring_to_paypal, false)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    # Handle the action parameter to determine the live action
    # socket = assign_ui(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:request_paypal_approval_url, socket) do
    SubscriptionHelpers.request_paypal_approval_url(socket)
  end

  #   def handle_info({:subscription_status_update, %{subscription_data: params}}, socket) do
  #   # Process params
  #   {:noreply, socket}
  # end

  # # Future enhancement that adds metadata - old handlers still work!
  # def handle_info({:subscription_status_update, %{subscription_data: params, metadata: meta}}, socket) do
  #   # Process params with metadata
  #   {:noreply, socket}
  # end

  #   def handle_info({:subscription_error, %{error_reason: reason}}, socket) do
  #   # Process params
  #   {:noreply, socket}
  # end

  @impl true
  def handle_event("request_paypal_approval_url", _, socket) do
    send(self(), :request_paypal_approval_url)
    socket = assign(socket, transferring_to_paypal: true)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <PartnersWeb.Layouts.app current_scope={@current_scope} flash={@flash}>
      <div class="max-w-4xl mx-auto px-4 py-8 h-screen flex justify-center">
        <div class="space-y-8 flex flex-col items-center"></div>
        <PartnersWeb.Subscription.Components.SubscriptionComponents.render {assigns} />
      </div>
    </PartnersWeb.Layouts.app>
    """
  end

  defp assign_ui(%{assigns: %{live_action: :paypal_cancel}} = socket) do
    socket
  end
end
