defmodule PartnersWeb.SubscriptionLive do
  @moduledoc """
  LiveView for managing PayPal subscription trial flows and state.

  ## Architecture Overview

  This LiveView implements a PayPal subscription flow with a clear separation of concerns:

  - **SubscriptionLive (this module)**: Handles LiveView lifecycle, event delegation,
    and subscription to PubSub events
  - **SubscriptionHelpers**: Contains all business logic for processing subscription actions
    and PayPal interactions
  - **SubscriptionComponents**: Handles UI rendering based on the current live_action

  ## Subscription Flow

  The PayPal subscription process follows these distinct phases:

  1. **Trial Initiation** (`:start_trial` live action)
     - User visits the trial subscription page
     - User clicks the "Subscribe" button
     - Request is delegated to SubscriptionHelpers which creates a PayPal subscription
     - User is redirected to PayPal's approval page

  2. **User Returns from PayPal** (Two possible paths)
     - **Successful approval** (`:paypal_return` live action)
       - User approves the subscription on PayPal's site
       - PayPal redirects to our return URL with subscription_id and token parameters
       - SubscriptionHelpers extracts these parameters and sets status to `:pending`
       - UI shows a processing/waiting state
       - Important: At this point, the user has only approved the subscription,
         but PayPal is still processing it on their end. The actual status updates
         come via webhooks, not through this return URL.

     - **User cancellation** (`:paypal_cancel` live action)
       - User cancels on PayPal's site
       - PayPal redirects to our cancel URL
       - SubscriptionHelpers sets subscription_status to `:cancelled`
       - UI offers option to try again

  3. **Asynchronous Webhook Updates**
     - After user approval, PayPal processes the subscription on their servers
     - PayPal sends webhook events to our webhook controller
     - Controller processes events and broadcasts via PubSub
     - This LiveView receives these broadcasts and updates the UI accordingly
     - Common status transitions: `:pending` → `:active` or `:pending` → `:failed`

  ## State Management

  The LiveView maintains state via socket assigns, which are managed by the helpers:
  - `subscription_status`: Current status (nil, :pending, :active, :cancelled, :failed)
  - `error_message`: Any error messages to display
  - `transferring_to_paypal`: Boolean for loading state
  - `subscription_id`: PayPal subscription ID
  - `paypal_token`: Token from PayPal for approved/cancelled subscriptions
  - `paypal_ba_token`: Billing agreement token (for return URLs)

  ## Event Handling

  - User-initiated events (like button clicks) are handled in this LiveView
  - Processing and state transitions are delegated to SubscriptionHelpers
  - PubSub messages from webhooks update the LiveView state in real-time
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
  def handle_params(params, _uri, socket) do
    # Handle the action parameter to determine the live action
    socket = SubscriptionHelpers.process_subscription_action(params, socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:request_paypal_approval_url, socket) do
    SubscriptionHelpers.request_paypal_approval_url(socket)
  end

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
end
