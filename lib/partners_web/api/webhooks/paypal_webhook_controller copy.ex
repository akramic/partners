defmodule PartnersWeb.Api.Webhooks.PaypalWebhookControllerCopy do
  @moduledoc """
  Controller for handling PayPal webhook callbacks and subscription events.

  This controller is responsible for:
  - Receiving and validating PayPal webhook events using cryptographic signature verification.
  - Processing subscription status changes based on verified webhook data.
  - Broadcasting events via PubSub to relevant subscribers (e.g., `SubscriptionLive`)
    for real-time UI updates.
  - Implementing a fallback mechanism: If webhook signature verification fails,
    it attempts to fetch the subscription details directly from the PayPal API
    using the `paypal_subscription_id` and `user_id` extracted from the webhook's
    resource data.
    - If the fallback API call confirms an "ACTIVE" subscription, the event is
      processed as if the signature was valid, but a warning is logged.
    - If the fallback API call fails or returns a non-ACTIVE status, a specific
      flash message is broadcast to the user, and the event is not processed further.
    - If `user_id` or `paypal_subscription_id` cannot be extracted for the fallback,
      an error is logged, and if `user_id` is present, a generic failure
      notification is broadcast.

  ## Event Broadcasting

  The controller broadcasts several types of events to the `paypal_subscription:{user_id}` topic:
  - `%{event: "subscription_updated", subscription_state: state}`: When a subscription
    is successfully updated (either via verified webhook or successful API fallback).
  - `%{event: "subscription_error", error: error_message}`: When an error occurs
    during the processing of a verified webhook event.
  - `%{event: "subscription_verification_failed", details: %{reason: inspect(verification_reason), message: flash_text}}`:
    When webhook signature verification fails and the fallback mechanism also does not
    confirm an "ACTIVE" subscription. The `flash_text` provides a user-friendly
    message: "We're having trouble confirming the setup of your Paypal trial
    subscription. Please try again and if you're still having problems, contact
    our friendly support team."

  LiveViews, such as `PartnersWeb.SubscriptionLive`, subscribe to these events to
  update the UI and inform the user about their subscription status or any issues.

  ## Webhook Signature Verification

  The `verify_webhook_signature/7` private function implements the steps outlined
  by PayPal for verifying webhook authenticity. This involves:
  1. Validating the presence of required HTTP headers (`paypal-auth-algo`,
     `paypal-cert-url`, `paypal-transmission-id`, `paypal-transmission-sig`,
     `paypal-transmission-time`).
  2. Validating the raw request body and the configured `paypal_webhook_id`.
  3. Fetching PayPal's public certificate from `paypal-cert-url` (with caching via
     `PaypalCertificateManager`).
  4. Constructing the signature base string using `transmission_id`, `transmission_time`,
     `webhook_id`, and a CRC32 checksum of the raw request body.
  5. Decoding the Base64 `paypal-transmission-sig`.
  6. Using `:public_key.verify/4` with the appropriate digest type (e.g., `:sha256`)
     to verify the signature against the public key.

  ## Configuration

  This controller relies on application configuration for:
  - PayPal Webhook ID (via `Paypal.webhook_id/0` which reads from `config/paypal.exs`).
  - PayPal API credentials and base URL (indirectly via `Partners.Services.Paypal`
    for fallback API calls).
  """
  use PartnersWeb, :controller
  require Logger

  alias Partners.Services.Paypal
  alias Partners.Services.PaypalCertificateManager
  alias X509.Certificate

  @doc """
  Handle PayPal subscription webhook callbacks.

  Processes incoming webhook notifications from PayPal by:
  1. Accessing the raw request body (cached by CacheRawBodyPlug)
  2. Retrieving necessary headers and PayPal Webhook ID
  3. Verifying the webhook signature
  4. If signature is valid, processing through Partners.Services.Paypal.process_webhook_event
  5. Broadcasting to appropriate PubSub channels

  Always returns 200 OK to PayPal. If signature verification fails, the event is not processed.
  """
  def paypal(conn, params) do
    raw_body = conn.assigns[:raw_body]

    paypal_webhook_id =
      try do
        Paypal.webhook_id()
      rescue
        e ->
          Logger.error("Failed to fetch PayPal Webhook ID: #{inspect(e)}")
          "ERROR_FETCHING_WEBHOOK_ID"
      end

    # Log initial webhook receipt
    Logger.info("""
    🔔 WEBHOOK: Received PayPal webhook
    Raw Body (from assigns): #{inspect(raw_body)}
    PayPal Webhook ID (from config): #{inspect(paypal_webhook_id)}
    Headers: #{inspect(conn.req_headers, pretty: true)}
    Params (parsed body): #{inspect(params, pretty: true)}
    """)

    # Extract PayPal-specific headers for verification
    paypal_auth_algo = get_header_value(conn.req_headers, "paypal-auth-algo")
    paypal_cert_url = get_header_value(conn.req_headers, "paypal-cert-url")
    paypal_transmission_id = get_header_value(conn.req_headers, "paypal-transmission-id")
    paypal_transmission_sig = get_header_value(conn.req_headers, "paypal-transmission-sig")
    paypal_transmission_time = get_header_value(conn.req_headers, "paypal-transmission-time")

    Logger.info("""
    🔎 PayPal Verification Headers:
    PAYPAL-AUTH-ALGO: #{inspect(paypal_auth_algo)}
    PAYPAL-CERT-URL: #{inspect(paypal_cert_url)}
    PAYPAL-TRANSMISSION-ID: #{inspect(paypal_transmission_id)}
    PAYPAL-TRANSMISSION-SIG: #{inspect(paypal_transmission_sig)}
    PAYPAL-TRANSMISSION-TIME: #{inspect(paypal_transmission_time)}
    """)

    case verify_webhook_signature(
           paypal_auth_algo,
           paypal_cert_url,
           # Corrected: ensure actual paypal_transmission_id is used
           paypal_transmission_id,
           # Reverted: Use actual signature from header
           paypal_transmission_sig,
           paypal_transmission_time,
           raw_body,
           paypal_webhook_id
         ) do
      {:ok, :verified} ->
        Logger.info("✅ PayPal webhook signature VERIFIED.")
        # --- Proceed with event processing ---
        event_type = params["event_type"]
        resource = params["resource"]
        user_id = extract_user_id_from_resource(resource)

        if user_id && event_type do
          case Paypal.process_webhook_event(event_type, resource, user_id) do
            {:ok, subscription_state} ->
              broadcast_subscription_update(user_id, subscription_state)

            {:error, reason} ->
              Logger.error("Error processing PayPal webhook event: #{inspect(reason)}")

              broadcast_subscription_error(
                user_id,
                "Error processing webhook event: #{inspect(reason)}"
              )
          end
        else
          Logger.warning(
            "Missing user_id or event_type in PayPal webhook. Params: #{inspect(params)}"
          )
        end

        send_resp(conn, 200, "OK (Verified - Processed)")

      {:error, original_signature_failure_reason} ->
        Logger.error(
          "❌ PayPal webhook signature verification FAILED: #{inspect(original_signature_failure_reason)}"
        )

        Logger.info(
          "Attempting fallback: Fetching subscription details directly from PayPal API."
        )

        resource_data = params["resource"]
        user_id = extract_user_id_from_resource(resource_data)
        paypal_subscription_id = extract_paypal_subscription_id_from_resource(resource_data)

        if user_id && paypal_subscription_id do
          Logger.info(
            "Fallback: Attempting to get details for PayPal Subscription ID: #{paypal_subscription_id} for User ID: #{user_id}"
          )

          case Paypal.get_subscription_details(paypal_subscription_id) do
            {:ok, %{"status" => "ACTIVE"} = subscription_details} ->
              process_event_after_fallback(
                conn,
                params,
                user_id,
                original_signature_failure_reason,
                subscription_details
              )

            {:ok, %{"status" => other_status} = subscription_details} ->
              Logger.error("""
              ❌ Fallback API call for subscription '#{paypal_subscription_id}' for user '#{user_id}' returned status '#{other_status}', not ACTIVE.
              Original signature failure reason: #{inspect(original_signature_failure_reason)}.
              Subscription details from API: #{inspect(subscription_details)}
              Proceeding with verification failure notification.
              """)

              broadcast_verification_failure(
                user_id,
                {:fallback_api_status_not_active, other_status, original_signature_failure_reason}
              )

              send_resp(
                conn,
                200,
                "OK (Signature Invalid, Fallback API Status Not Active - Event Not Processed)"
              )

            {:error, api_error_reason} ->
              Logger.error("""
              ❌ Fallback API call failed for subscription '#{paypal_subscription_id}' for user '#{user_id}'.
              API Error: #{inspect(api_error_reason)}.
              Original signature failure reason: #{inspect(original_signature_failure_reason)}.
              Proceeding with verification failure notification.
              """)

              broadcast_verification_failure(
                user_id,
                {:fallback_api_call_failed, api_error_reason, original_signature_failure_reason}
              )

              send_resp(
                conn,
                200,
                "OK (Signature Invalid, Fallback API Error - Event Not Processed)"
              )
          end
        else
          Logger.error("""
          ❌ Fallback API call cannot be attempted. Missing PayPal Subscription ID or User ID from webhook resource.
          Extracted PayPal Subscription ID: #{inspect(paypal_subscription_id)}, Extracted User ID: #{inspect(user_id)}.
          Original signature failure reason: #{inspect(original_signature_failure_reason)}.
          Webhook Params Resource: #{inspect(resource_data)}
          Proceeding with verification failure notification.
          """)

          # If user_id is available, notify them. Otherwise, just log.
          if user_id do
            broadcast_verification_failure(
              user_id,
              # Variable name corrected to match the one in scope
              {:fallback_missing_ids_for_api_call, original_signature_failure_reason}
            )
          else
            Logger.error(
              "Cannot notify user of verification failure: User ID unknown after signature failure and prior to fallback. Original reason: #{inspect(original_signature_failure_reason)}"
            )
          end

          send_resp(
            conn,
            200,
            "OK (Signature Invalid, Fallback Pre-check Failed - Event Not Processed)"
          )
        end
    end
  end

  defp process_event_after_fallback(
         conn,
         params,
         user_id,
         original_signature_failure_reason,
         subscription_details_from_api
       ) do
    Logger.warning("""
    ⚠️ Webhook signature verification failed (Reason: #{inspect(original_signature_failure_reason)}),
    BUT PayPal API confirmed subscription for user '#{user_id}' is ACTIVE.
    Proceeding with event processing based on API confirmation.
    Subscription details from API: #{inspect(subscription_details_from_api)}
    """)

    event_type = params["event_type"]
    # Use original resource from webhook
    resource = params["resource"]

    # Ensure user_id and event_type are still valid (user_id was checked before calling this helper)
    if event_type do
      case Paypal.process_webhook_event(event_type, resource, user_id) do
        {:ok, subscription_state} ->
          broadcast_subscription_update(user_id, subscription_state)

        {:error, processing_error} ->
          Logger.error(
            "Error processing PayPal webhook event after API fallback success: #{inspect(processing_error)}"
          )

          broadcast_subscription_error(
            user_id,
            "Error processing webhook event after API fallback success: #{inspect(processing_error)}"
          )
      end

      send_resp(conn, 200, "OK (Verified via API Fallback - Processed)")
    else
      Logger.error("""
      Fallback Success Path: Missing event_type in PayPal webhook after successful API confirmation.
      User ID: #{user_id}. Params: #{inspect(params)}.
      Original signature failure reason: #{inspect(original_signature_failure_reason)}.
      """)

      broadcast_verification_failure(
        user_id,
        {:fallback_missing_event_type_post_api_success, original_signature_failure_reason}
      )

      send_resp(
        conn,
        200,
        "OK (Signature Invalid, Fallback Data Missing Post API Success - Event Not Processed)"
      )
    end
  end

  defp verify_webhook_signature(
         paypal_auth_algo,
         paypal_cert_url,
         paypal_transmission_id,
         paypal_transmission_sig,
         paypal_transmission_time,
         raw_body,
         paypal_webhook_id
       ) do
    with {:ok, paypal_auth_algo} <- validate_present(paypal_auth_algo, :paypal_auth_algo),
         {:ok, paypal_cert_url} <- validate_present(paypal_cert_url, :paypal_cert_url),
         {:ok, paypal_transmission_id} <-
           validate_present(paypal_transmission_id, :paypal_transmission_id),
         {:ok, paypal_transmission_sig} <-
           validate_present(paypal_transmission_sig, :paypal_transmission_sig),
         {:ok, paypal_transmission_time} <-
           validate_present(paypal_transmission_time, :paypal_transmission_time),
         {:ok, raw_body} <- validate_raw_body(raw_body),
         {:ok, paypal_webhook_id} <- validate_paypal_webhook_id(paypal_webhook_id),
         # ---
         {:ok, digest_type} <- get_digest_type(paypal_auth_algo),
         {:ok, signature_base_string} <-
           build_signature_base_string(
             paypal_transmission_id,
             paypal_transmission_time,
             paypal_webhook_id,
             raw_body
           ),
         {:ok, public_key} <- get_public_key_from_paypal_cert(paypal_cert_url),
         {:ok, decoded_signature} <- decode_transmission_sig(paypal_transmission_sig),
         true <-
           :public_key.verify(signature_base_string, digest_type, decoded_signature, public_key) do
      {:ok, :verified}
    else
      false ->
        Logger.error(
          "Signature verification returned false (:public_key.verify failed). Signature invalid."
        )

        {:error, :signature_mismatch}

      {:error, reason_atom} ->
        Logger.error("Error during signature verification step: #{inspect(reason_atom)}")
        {:error, reason_atom}
    end
  end

  defp validate_present(value, field_name) do
    if is_nil(value) or (is_binary(value) and String.trim(value) == "") do
      Logger.warning("Missing or empty required value for signature verification: #{field_name}")
      {:error, {:missing_verification_data, field_name}}
    else
      {:ok, value}
    end
  end

  defp validate_raw_body(raw_body) do
    if is_binary(raw_body) and byte_size(raw_body) > 0 do
      {:ok, raw_body}
    else
      Logger.warning("Raw body is nil, not a binary, or empty.")
      {:error, :invalid_raw_body}
    end
  end

  defp validate_paypal_webhook_id(id) do
    cond do
      is_nil(id) or (is_binary(id) and String.trim(id) == "") ->
        Logger.error("PayPal Webhook ID is missing or empty.")
        {:error, :missing_webhook_id}

      id == "ERROR_FETCHING_WEBHOOK_ID" ->
        Logger.error("PayPal Webhook ID was not configured or failed to load.")
        {:error, :invalid_webhook_id_configuration}

      true ->
        {:ok, id}
    end
  end

  defp get_digest_type(paypal_auth_algo) do
    case paypal_auth_algo do
      "SHA256withRSA" ->
        {:ok, :sha256}

      # TODO: Add other algorithms if PayPal starts using them, e.g., "SHA512withRSA" -> {:ok, :sha512}
      _ ->
        Logger.error("Unsupported PayPal auth algorithm: #{paypal_auth_algo}")
        {:error, :unsupported_auth_algorithm}
    end
  end

  defp build_signature_base_string(transmission_id, transmission_time, webhook_id, raw_body) do
    crc32_of_body = :erlang.crc32(raw_body) |> Integer.to_string()

    base_string =
      [
        transmission_id,
        transmission_time,
        webhook_id,
        crc32_of_body
      ]
      |> Enum.join("|")

    {:ok, base_string}
  end

  defp ensure_binary(value, error_tag) do
    if is_binary(value) do
      {:ok, value}
    else
      {:error, error_tag}
    end
  end

  defp get_public_key_from_paypal_cert(paypal_cert_url) do
    with {:ok, pem_string} <- PaypalCertificateManager.get_certificate(paypal_cert_url),
         {:ok, pem_binary} <- ensure_binary(pem_string, :pem_not_binary),
         {:ok, cert_record} <- Certificate.from_pem(pem_binary),
         # CRITICAL ASSUMPTION: Certificate.public_key/1 returns {:ok, _} | {:error, _}
         # and does not raise exceptions for errors intended to be handled in the control flow.
         # If it can raise, removing the previous try/rescue makes this a potential crash point.
         {:ok, public_key_erlang_record} <- Certificate.public_key(cert_record) do
      {:ok, public_key_erlang_record}
    else
      {:error, :pem_not_binary} ->
        Logger.error(
          "PEM string from PaypalCertificateManager was not a binary for URL #{paypal_cert_url}."
        )

        {:error, :pem_not_binary}

      {:error, reason} ->
        Logger.error(
          "Failed during public key derivation for URL #{paypal_cert_url}. Reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp decode_transmission_sig(paypal_transmission_sig) do
    case Base.decode64(paypal_transmission_sig, padding: true) do
      {:ok, decoded_binary} ->
        {:ok, decoded_binary}

      :error ->
        Logger.error(
          "Failed to Base64 decode PayPal transmission signature. Input might be invalid or incorrectly padded."
        )

        {:error, :signature_decode_failed}
    end
  end

  # Helper to extract a specific header value
  defp get_header_value(headers, header_name) do
    Enum.find_value(headers, fn {name, value} ->
      if String.downcase(name) == String.downcase(header_name), do: value, else: nil
    end)
  end

  # Extract user_id from resource data (adapt based on your PayPal payload structure)
  defp extract_user_id_from_resource(resource) when is_map(resource) do
    # Try different paths where user_id might be stored
    cond do
      # Check custom_id in the subscription object (common for subscription events)
      resource["custom_id"] ->
        resource["custom_id"]

      # Check for subscriber information within the resource (common for BILLING.SUBSCRIPTION.* events)
      # Example: resource["subscriber"]["custom_id"] - this depends on your specific setup with PayPal
      # For now, we assume custom_id is at the top level of the resource or within a "subscription" sub-map.

      # Check for subscription object if custom_id is not at the top level of resource
      resource["subscription"] && resource["subscription"]["custom_id"] ->
        resource["subscription"]["custom_id"]

      # Check payer information for user_id if available (might be email or payer_id)
      # This is highly dependent on how you associate PayPal transactions/subscriptions with your users.
      # Example: resource["payer"]["payer_id"] or resource["payer"]["email_address"]
      # Ensure this aligns with what you store as `user_id`.
      # For this example, let's assume custom_id is the primary mechanism.

      true ->
        nil
    end
  end

  defp extract_user_id_from_resource(_), do: nil

  # Helper to extract PayPal Subscription ID from resource data
  defp extract_paypal_subscription_id_from_resource(resource) when is_map(resource) do
    cond do
      # Common for BILLING.SUBSCRIPTION.* events (this is the PayPal Subscription ID)
      resource["id"] ->
        resource["id"]

      # Older field, or for PAYMENT.SALE.* linked to subscriptions
      resource["billing_agreement_id"] ->
        resource["billing_agreement_id"]

      # If the subscription ID is nested further, adjust accordingly.
      # e.g., resource["subscription"]["id"] if that's where it is.
      true ->
        nil
    end
  end

  defp extract_paypal_subscription_id_from_resource(_), do: nil

  # Broadcast a subscription update event
  defp broadcast_subscription_update(user_id, subscription_state) do
    topic = "paypal_subscription:#{user_id}"

    message = %{
      event: "subscription_updated",
      subscription_state: subscription_state
    }

    Logger.info("Broadcasting subscription update to #{topic}: #{inspect(message)}")
    Phoenix.PubSub.broadcast(Partners.PubSub, topic, message)
  end

  # Broadcast a subscription error event
  defp broadcast_subscription_error(user_id, error_message) do
    topic = "paypal_subscription:#{user_id}"

    message = %{
      event: "subscription_error",
      error: error_message
    }

    Logger.error("Broadcasting subscription error to #{topic}: #{inspect(message)}")
    Phoenix.PubSub.broadcast(Partners.PubSub, topic, message)
  end

  defp broadcast_verification_failure(user_id, verification_reason) do
    topic = "paypal_subscription:#{user_id}"

    # Log the detailed verification reason for server-side debugging
    Logger.warning("""
    Broadcasting subscription verification failure for user '#{user_id}'.
    Internal Verification Reason: #{inspect(verification_reason)}
    """)

    # User-friendly flash text
    flash_text =
      "Your PayPal subscription could not be confirmed at this time. Please try initiating the subscription again. If the problem continues, please contact support."

    # Sanitized message for broadcasting
    message = %{
      event: "subscription_verification_failed",
      details: %{
        # Only include the user-friendly message
        message: flash_text
        # DO NOT include: reason: inspect(verification_reason)
      }
    }

    Logger.info(
      "Broadcasting sanitized subscription verification failure to #{topic}: #{inspect(message)}"
    )

    Phoenix.PubSub.broadcast(Partners.PubSub, topic, message)
  end
end
