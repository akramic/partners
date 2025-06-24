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
     * **Pending Approval Check** - After a configurable timeout period (default: 60 seconds),
       if no webhook events are received confirming activation, the LiveView will:
       * Automatically check the subscription status via PayPal API
       * Update the UI based on the retrieved status
       * Handle edge cases where webhooks might be delayed or lost
       * This is managed through the `handle_info({:check_subscription_status, subscription_id}, socket)` handler
       * The check is initiated by `SubscriptionHelpers.schedule_subscription_status_check/2`

  ## PayPal Subscription Event Types and Statuses

  ### Event Types and Associated Statuses

  * `BILLING.SUBSCRIPTION.CREATED`
    - Associated status: `APPROVAL_PENDING` (The subscription is created but not yet approved by the buyer)

  * `BILLING.SUBSCRIPTION.ACTIVATED`
    - Associated status: `ACTIVE` (The subscription is now active)

  * `BILLING.SUBSCRIPTION.UPDATED`
    - May not change status directly, but updates subscription details

  * `BILLING.SUBSCRIPTION.CANCELLED`
    - Associated status: `CANCELLED` (The subscription has been terminated)

  * `BILLING.SUBSCRIPTION.SUSPENDED`
    - Associated status: `SUSPENDED` (The subscription is temporarily paused)

  * `BILLING.SUBSCRIPTION.EXPIRED`
    - Associated status: `EXPIRED` (The subscription has reached its end date)

  * `BILLING.SUBSCRIPTION.PAYMENT.FAILED`
    - May lead to `SUSPENDED` status if multiple failures occur

  * `PAYMENT.SALE.COMPLETED`
    - Confirms successful payment, maintains `ACTIVE` status

  ### Complete List of Official Subscription Statuses

  * `APPROVAL_PENDING` - Initial state when subscription is created
  * `APPROVED` - Intermediate state after buyer approval but before activation (NOTE: This status is not associated with any webhook event; it's detected through return URL navigation)
  * `ACTIVE` - Regular active subscription state
  * `SUSPENDED` - Temporarily paused subscription
  * `CANCELLED` - Permanently terminated subscription
  * `EXPIRED` - Subscription that has reached its end date

  ### Status Transitions

  Typical status flow:
  1. `APPROVAL_PENDING` (triggered by `BILLING.SUBSCRIPTION.CREATED`)
  2. `APPROVED` (after buyer approves on PayPal site)
  3. `ACTIVE` (triggered by `BILLING.SUBSCRIPTION.ACTIVATED`)

  Subscription can then transition to:
  - `SUSPENDED` (triggered by `BILLING.SUBSCRIPTION.SUSPENDED`)
  - `CANCELLED` (triggered by `BILLING.SUBSCRIPTION.CANCELLED`)
  - `EXPIRED` (triggered by `BILLING.SUBSCRIPTION.EXPIRED`)

  Note: Refer to PayPal's official documentation for complete details and any updates
  to these statuses or event types.

  ## Pending Approval Check

  A safety mechanism is implemented to handle cases where webhooks are delayed or missing:

  * After a configurable timeout period (default: 120 seconds) following subscription creation,
    if a subscription remains in `APPROVAL_PENDING` state with no webhook events confirming
    activation, the LiveView will:
    * Automatically check the subscription status via PayPal API
    * Update the UI based on the direct API check result
    * Handle various possible states (active, still pending, cancelled, etc.)
    * Show appropriate user feedback based on the found status

  This ensures users aren't stuck in loading screens if PayPal webhooks are delayed or fail to arrive.

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

  This mount function handles two scenarios:
  - When a user_id parameter is provided, it calls `maybe_redirect_if_user_not_found/2` which:
    * Validates the user_id is a valid string
    * Looks up the user in the database using the ID to ensure it exists
    * If user is found, subscribes to PayPal event notifications for this user via PubSub
    * If user_id validation fails or user is not found in the database, redirects to home page with error message
  - When no user_id is provided, it immediately redirects to the home page with an error message
  """
  @impl true
  def mount(%{"user_id" => user_id}, _session, socket) do
    # Use the real user from the current scope
    Logger.info("Mounting Subscription LiveView live_action: #{socket.assigns.live_action}")
    Logger.info("Subscription LiveView mounted with user_id: #{inspect(user_id)}")
    Logger.info("Live action: #{socket.assigns.live_action}")

    maybe_redirect_if_user_not_found(user_id, socket)
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> put_flash(:error, "No user provided")

    {:ok, push_navigate(socket, to: ~p"/")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # Handle the action parameter to determine the live action
    socket = SubscriptionHelpers.process_subscription_action(params, socket)
    {:noreply, socket}
  end

  @doc """
  Handles various information messages sent to the LiveView process.

  There are several types of messages handled:

  * `:request_paypal_approval_url` - Initiates the PayPal approval URL request process
    to begin subscription creation.

  * `{:subscription_status_update, %{subscription_data: params}}` - Processes webhook
    events from PayPal indicating subscription status changes. Updates the UI based on
    the new subscription status.

  * `{:subscription_error, %{error_reason: reason}}` - Handles any errors that occur
    during the subscription process.

  * `{:check_subscription_status, subscription_id}` - Triggered by the timeout set in the
    `process_subscription_status_update` function when a subscription is created. Delegates to
    the `SubscriptionHelpers` module to check the current status of the subscription directly
    via the PayPal API and update the UI accordingly. This is a safety mechanism to handle cases
    where webhooks might be delayed or missing.
  """

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

  def handle_info({:check_subscription_status, subscription_id}, socket) do
    SubscriptionHelpers.process_get_subscription_status_after_timeout(subscription_id, socket)
  end

  # # Future enhancement that adds metadata - old handlers still work!
  # def handle_info({:subscription_status_update, %{subscription_data: params, metadata: meta}}, socket) do
  #   # Process params with metadata
  #   {:noreply, socket}
  # end

  @impl true
  def handle_event("request_paypal_approval_url", %{"retry" => "true"}, socket) do
    Logger.info("🔔 User #{socket.assigns.user.id} retrying subscription setup")
    send(self(), :request_paypal_approval_url)
    socket = assign(socket, transferring_to_paypal: true, retry: true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("request_paypal_approval_url", _payload, socket) do
    send(self(), :request_paypal_approval_url)
    socket = assign(socket, transferring_to_paypal: true, retry: false)
    {:noreply, socket}
  end

  # Helper function that validates a user_id and fetches the corresponding user.

  # This function:
  # 1. Validates that the user_id is a valid string
  # 2. Attempts to fetch the user from the database using Partners.Accounts.get_user/1
  # 3. If successful, sets up PubSub subscription for PayPal events and assigns the user to the socket
  # 4. If validation fails or user is not found, redirects to the home page with an error message

  defp maybe_redirect_if_user_not_found(user_id, socket) do
    with true <- is_binary(user_id),
         found_user when not is_nil(found_user) <- Partners.Accounts.get_user(user_id) do
      # Subscribe to the PayPal subscription topic if the socket is connected
      if connected?(socket) do
        subscription_topic = "paypal_subscription:#{user_id}"
        Logger.info("Subscribing to PayPal subscription topic: #{subscription_topic}")
        :ok = Phoenix.PubSub.subscribe(Partners.PubSub, subscription_topic)
        Logger.info("Successfully subscribed to PayPal subscription topic")
      else
        Logger.info("Socket not connected yet, skipping PubSub subscription")
      end

      # Return the socket with all the necessary assigns
      {:ok,
       socket
       |> assign(:page_title, "Subscription setup")
       |> assign(:subscription_status, nil)
       |> assign(:error_message, nil)
       |> assign(:approval_url, nil)
       |> assign(:subscription_id, nil)
       |> assign(:transferring_to_paypal, false)
       |> assign(:retry, false)
       |> assign(user: found_user)}
    else
      false ->
        Logger.error("Invalid user ID provided: #{inspect(user_id)}")

        {:ok,
         socket
         |> put_flash(:error, "Invalid user data")
         |> push_navigate(to: ~p"/")}

      nil ->
        Logger.error("User with ID #{inspect(user_id)} not found, redirecting to home page")

        {:ok,
         socket
         |> put_flash(:error, "User not found")
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <PartnersWeb.Layouts.app current_scope={@current_scope} flash={@flash}>
      <div class="max-w-6xl mx-auto px-4 py-8 h-screen flex justify-center mt-[clamp(2rem,8vw,4rem)]">
        <div class="space-y-8 flex flex-col items-center"></div>
        <PartnersWeb.Subscription.Components.SubscriptionComponents.render {assigns} />
      </div>
    </PartnersWeb.Layouts.app>
    """
  end
end
