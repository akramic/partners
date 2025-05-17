defmodule PartnersWeb.SubscriptionLive do
  @moduledoc """
  LiveView for managing PayPal subscription trial flows and state.

  ## Subscription Flow Overview

  This LiveView handles the complete PayPal subscription lifecycle:

  1. **Trial Initiation** (`:start_trial` live action)
     * User visits the subscription page with the `:start_trial` live action
     * User clicks "Start Trial" button which triggers `handle_event("request_paypal_approval_url")`
     * `SubscriptionHelpers.request_paypal_approval_url/1` makes the API call to PayPal
     * PayPal creates a subscription in APPROVAL_PENDING state and returns an approval_url

  2. **PayPal Redirection**
     * User is redirected to PayPal's external approval page via `redirect(socket, external: approval_url)`
     * User authenticates with PayPal if needed
     * User reviews the subscription terms (trial period, future billing, etc.)
     * User makes a choice to either approve or cancel the subscription

  3. **Return Processing** (critical stage)
     * `:paypal_return` live action - Triggered when user approves the subscription
       IMPORTANT: At this point, the user has approved the subscription on PayPal's site,
       but PayPal hasn't finalized all processing. The LiveView shows a loading screen with
       "Thank you for your subscription! We are setting up your account now. Please wait..."
       The UI displays a loading indicator while awaiting webhook notifications for final confirmation.
       No further user action is required during this transitional state.

     * `:paypal_cancel` live action - Triggered when user cancels at PayPal's site
       This indicates the user declined to proceed with the subscription.
       The UI provides an option for the user to retry the subscription process,
       allowing them to reconsider their decision and restart the PayPal approval flow.

  4. **Webhook Event Handling**
     * `PartnersWeb.Api.Webhooks.PaypalWebhookController` receives notifications from PayPal
     * The controller validates signatures and processes events like `BILLING.SUBSCRIPTION.ACTIVATED`
     * The controller explicitly broadcasts these events via Phoenix.PubSub to this LiveView
     * This LiveView receives the broadcasts via `handle_info({:subscription_status_update, ...}, socket)`
     * UI updates happen automatically with no page refresh needed

  ## Key Implementation Details

  * Subscribes to topic `paypal_subscription:{user_id}` for receiving PayPal event broadcasts
  * Maintains subscription state in socket assigns for reactive UI updates
  * Delegates PayPal API interactions to `SubscriptionHelpers` module
  * Renders UI through `PartnersWeb.Subscription.Components.SubscriptionComponents`
  * Supports states: nil (initial), pending, active, cancelled, error
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

  def handle_info({:subscription_status_update, %{subscription_data: params}}, socket) do
    # Process params
    Logger.info("🔔 Subscription status update received: #{inspect(params)}")
    socket = SubscriptionHelpers.process_subscription_status_update(params, socket)
    {:noreply, socket}
  end

  def handle_info({:subscription_error, %{error_reason: reason}}, socket) do
    # Process params
    Logger.error("❌ Error processing subscription: #{inspect(reason)}")
    {:noreply, socket}
  end

  # # Future enhancement that adds metadata - old handlers still work!
  # def handle_info({:subscription_status_update, %{subscription_data: params, metadata: meta}}, socket) do
  #   # Process params with metadata
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
end
