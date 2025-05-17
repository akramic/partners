defmodule PartnersWeb.Api.Webhooks.PaypalWebhookController do
  @moduledoc """
  Controller for handling PayPal webhook callbacks and subscription events.
  It verifies the webhook signature and processes the event accordingly.

  ## Event Types

  PayPal sends multiple types of webhook events that need different handling:

  ### Trial Subscription Events (require UI updates)

  These events occur during the trial subscription lifecycle and require updating the UI:

  - `BILLING.SUBSCRIPTION.CREATED` - Initial creation of subscription (status: APPROVAL_PENDING)
    * Contains the approval URL that the user needs to visit
    * Includes subscription ID and custom_id (our internal user ID)
    * User must approve this subscription by visiting the approval URL

  - `BILLING.SUBSCRIPTION.ACTIVATED` - User approved the subscription in PayPal
    * Indicates successful approval and start of the trial period
    * Status changes from APPROVAL_PENDING to ACTIVE
    * Trial period begins from this point (typically 7 days)
    * No payment is collected at this stage

  - `BILLING.SUBSCRIPTION.CANCELLED` - User or merchant canceled before trial ends
    * Can be initiated by either the user or our application
    * No charges if canceled during the trial period
    * UI should be updated to show subscription is no longer active

  - `BILLING.SUBSCRIPTION.SUSPENDED` - Trial temporarily suspended
    * Subscription paused but not terminated
    * Can be reactivated later
    * Typically happens when there's a payment issue after the trial

  For these events, we broadcast via PubSub to update the UI in SubscriptionLive
  when the user is actively on the website.

  ### Payment Events (require database updates)

  These events occur during the normal payment lifecycle and require database updates:

  - `PAYMENT.SALE.COMPLETED` - Payment successfully processed
    * Happens when the trial ends and the first regular payment is collected
    * Also occurs for each recurring payment (monthly/annually)
    * Contains payment details including amount, fees, and net amount

  - `PAYMENT.SALE.DENIED` - Payment was denied
    * Payment method declined or insufficient funds
    * May lead to subscription suspension if not resolved
    * Requires user intervention to update payment method

  - `PAYMENT.SALE.REFUNDED` - Payment was refunded
    * Full or partial refund processed
    * May require adjusting subscription status or extending service period
    * Should trigger email notification to the user

  - `BILLING.SUBSCRIPTION.PAYMENT.FAILED` - Recurring payment failed
    * PayPal will retry payment according to retry rules (typically 3 attempts)
    * After final retry failure, subscription may be suspended
    * Should trigger communication to user about payment issues

  - `BILLING.SUBSCRIPTION.EXPIRED` - Subscription reached end date
    * Normal termination at the end of subscription term
    * Different from cancellation (which can happen anytime)
    * May trigger renewal offers or re-subscription options

  For these events, we update the database and send email notifications
  as they might occur when the user is not actively using the application.

  ## Webhook Verification Process

  PayPal webhooks include security headers that allow us to verify the authenticity of each request:

  1. `paypal-transmission-id` - Unique webhook transmission ID
  2. `paypal-transmission-time` - Timestamp when the webhook was sent
  3. `paypal-cert-url` - URL to download the PayPal certificate for verification
  4. `paypal-auth-algo` - Algorithm used for the signature (typically SHA256withRSA)
  5. `paypal-transmission-sig` - The signature to verify against

  Our `PaypalWebhookVerifier` service handles the cryptographic verification by:
  1. Extracting these headers from the request
  2. Reading the raw body of the webhook payload
  3. Verifying the signature using our locally stored PayPal certificate
  4. Returning {:ok, result} on success or {:error, reason} on failure

  Even if verification fails, we return HTTP 200 to PayPal to prevent unnecessary retries,
  but log the error and don't process the webhook payload.
  """

  use PartnersWeb, :controller
  require Logger

  alias Partners.Services.PaypalWebhookVerifier
  alias Phoenix.PubSub

  def paypal(conn, params) do
    Logger.info("CONN: #{inspect(conn)}")
    Logger.info("PARAMS: #{inspect(params)}")

    case PaypalWebhookVerifier.validate_webhook_signature(conn) do
      {:ok, result} ->
        Logger.info("✅ PayPal webhook signature VERIFIED: #{inspect(result)}")
        # Function for processing successful webhook
        process_validated_webhook(params)

        send_resp(
          conn,
          200,
          "Webhook processed successfully."
        )

      {:error, reason} ->
        Logger.error("❌ PayPal webhook signature verification FAILED: #{inspect(reason)}")
        # Function for processing failed webhook
        process_invalid_webhook(reason, params)

        send_resp(
          conn,
          200,
          "Invalid webhook signature."
        )
    end
  end

  defp process_validated_webhook(%{"event_type" => "BILLING.SUBSCRIPTION.CREATED"} = params) do
    user_id = params["resource"]["custom_id"]
    topic = "paypal_subscription:#{user_id}"

    Logger.info("✅ Processing validated PayPal webhook with event type: #{params["event_type"]}")
    Logger.info("✅ Broadcasting to topic: #{topic}")

    PubSub.broadcast(
      Partners.PubSub,
      topic,
      {:subscription_status_update, %{subscription_data: params}}
    )
  end

  defp process_validated_webhook(%{"event_type" => "BILLING.SUBSCRIPTION.ACTIVATED"} = params) do
    user_id = params["resource"]["custom_id"]
    topic = "paypal_subscription:#{user_id}"

    Logger.info("✅ Processing validated PayPal webhook with event type: #{params["event_type"]}")
    Logger.info("✅ Broadcasting to topic: #{topic}")

    PubSub.broadcast(
      Partners.PubSub,
      topic,
      {:subscription_status_update, %{subscription_data: params}}
    )
  end

  defp process_validated_webhook(%{"event_type" => "BILLING.SUBSCRIPTION.CANCELLED"} = params) do
    user_id = params["resource"]["custom_id"]
    topic = "paypal_subscription:#{user_id}"

    Logger.info("✅ Processing validated PayPal webhook with event type: #{params["event_type"]}")
    Logger.info("✅ Broadcasting to topic: #{topic}")

    PubSub.broadcast(
      Partners.PubSub,
      topic,
      {:subscription_status_update, %{subscription_data: params}}
    )
  end

  defp process_validated_webhook(%{"event_type" => "BILLING.SUBSCRIPTION.SUSPENDED"} = params) do
    user_id = params["resource"]["custom_id"]
    topic = "paypal_subscription:#{user_id}"

    Logger.info("✅ Processing validated PayPal webhook with event type: #{params["event_type"]}")
    Logger.info("✅ Broadcasting to topic: #{topic}")

    PubSub.broadcast(
      Partners.PubSub,
      topic,
      {:subscription_status_update, %{subscription_data: params}}
    )
  end

  # Catch-all for other event types - log but don't broadcast
  defp process_validated_webhook(params) do
    Logger.info(
      "✅ Processing validated PayPal webhook with unhandled event type: #{params["event_type"]}"
    )
  end

  defp process_invalid_webhook(reason, params) do
    # Extract user_id directly from params with defensive coding against nil or invalid structure
    user_id =
      case params do
        %{"resource" => %{"custom_id" => custom_id}}
        when is_binary(custom_id) and custom_id != "" ->
          custom_id

        _ ->
          Logger.warning(
            "❌ No valid user_id found in params for invalid webhook: #{inspect(params)}"
          )

          nil
      end

    Logger.error("❌ Processing invalid PayPal webhook: #{inspect(reason)}")

    if user_id do
      topic = "paypal_subscription:#{user_id}"
      Logger.info("✅ Broadcasting error to topic: #{topic}")

      PubSub.broadcast(
        Partners.PubSub,
        topic,
        {:subscription_error, %{error_reason: reason}}
      )
    end
  end
end
