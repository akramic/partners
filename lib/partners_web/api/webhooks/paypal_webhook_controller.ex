defmodule PartnersWeb.Api.Webhooks.PaypalWebhookController do
  @moduledoc """
  Controller for handling PayPal webhook callbacks and subscription events.

  This controller is responsible for:
  - Receiving and validating PayPal webhook events
  - Processing subscription status changes
  - Broadcasting events via PubSub to relevant subscribers
  - Handling subscription return URLs (success/cancel)

  ## Event Broadcasting

  The controller broadcasts two types of events:
  1. Profile-specific events on topic "subscription:[profile_id]"
     Message: {:subscription_updated, event_data}
  2. Global events on topic "subscriptions"
     Message: {:subscription_event, event_data}

  LiveViews can subscribe to these events using:
      Phoenix.PubSub.subscribe(Partners.PubSub, "subscription:" <> profile_id)
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
          #  paypal_transmission_id,
           transmission_d = "not genuine" <> paypal_transmission_id,
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

      {:error, reason} ->
        Logger.error("❌ PayPal webhook signature verification FAILED: #{inspect(reason)}")
        Logger.info("Event NOT processed due to signature verification failure.")

        # Attempt to get user_id for notification
        # params are available in this scope. resource might be in params["resource"]
        resource_for_error_path = params["resource"]
        user_id_for_error_path = extract_user_id_from_resource(resource_for_error_path)

        if user_id_for_error_path do
          broadcast_verification_failure(user_id_for_error_path, reason)
        else
          Logger.warning(
            "Could not extract user_id from webhook params for verification failure notification. Params: #{inspect(params)}"
          )
        end

        send_resp(conn, 200, "OK (Signature Invalid - Event Not Processed)")
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

      other_error ->
        Logger.error(
          "Unexpected error or invalid input during signature verification: #{inspect(other_error)}"
        )

        {:error, :unexpected_verification_error}
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

  defp get_public_key_from_paypal_cert(paypal_cert_url) do
    with {:ok, pem_string} <- PaypalCertificateManager.get_certificate(paypal_cert_url),
         # Ensure pem_string is binary
         true <- is_binary(pem_string),
         # Parse PEM to cert record
         {:ok, cert_record} <- Certificate.from_pem(pem_string) do
      # If all above are successful, cert_record is available.
      # Now, extract the public key. Certificate.public_key/1 returns SubjectPublicKeyInfo.t() directly or raises.
      try do
        public_key_erlang_record = Certificate.public_key(cert_record)
        # Success: return {:ok, key_record} which is expected by the caller's 'with' chain
        {:ok, public_key_erlang_record}
      rescue
        e ->
          # Log the exception and return an error tuple
          Logger.error(
            "Exception from Certificate.public_key/1 for URL #{paypal_cert_url}: #{inspect(e)}"
          )

          {:error, {:public_key_extraction_failed, :exception_in_public_key_call}}
      end
    else
      # This 'else' block handles failures from the 'with' conditions:
      # PaypalCertificateManager.get_certificate, is_binary, Certificate.from_pem

      # From PaypalCertificateManager
      {:error, cert_manager_reason} when is_atom(cert_manager_reason) ->
        Logger.error(
          "Failed to get certificate via PaypalCertificateManager for URL #{paypal_cert_url}: #{inspect(cert_manager_reason)}"
        )

        {:error, {:certificate_fetch_failed, cert_manager_reason}}

      # From `true <- is_binary(pem_string)`
      false ->
        Logger.error(
          "PEM string from PaypalCertificateManager was not a binary for URL #{paypal_cert_url}."
        )

        {:error, :pem_not_binary}

      # From `Certificate.from_pem(pem_string)`
      {:error, from_pem_reason} ->
        Logger.error(
          "Failed to parse PEM with Certificate.from_pem/1 for URL #{paypal_cert_url}: #{inspect(from_pem_reason)}"
        )

        {:error, {:public_key_extraction_failed, from_pem_reason}}

      # This catch-all should ideally not be hit if the patterns above are exhaustive for known 'with' failures.
      unexpected_with_failure ->
        Logger.error(
          "Unexpected failure in 'with' chain setup of get_public_key_from_paypal_cert for URL #{paypal_cert_url}: #{inspect(unexpected_with_failure)}"
        )

        {:error, :unexpected_error_in_get_public_key_setup}
    end
  end

  defp decode_transmission_sig(paypal_transmission_sig) do
    try do
      {:ok, Base.decode64!(paypal_transmission_sig, padding: true)}
    rescue
      e in ArgumentError ->
        Logger.error("Failed to Base64 decode PayPal transmission signature: #{inspect(e)}")
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

      # Check for subscription object
      resource["subscription"] && resource["subscription"]["custom_id"] ->
        resource["subscription"]["custom_id"]

      # Additional checks as needed for different event types

      true ->
        nil
    end
  end

  defp extract_user_id_from_resource(_), do: nil

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

    message = %{
      event: "subscription_verification_failed",
      details: %{
        reason: inspect(verification_reason),
        message:
          "There was a problem verifying the payment notification from PayPal. Your transaction may not have been processed correctly. Please contact support if the issue persists or you don't see your subscription updated shortly."
      }
    }

    Logger.info("Broadcasting subscription verification failure to #{topic}: #{inspect(message)}")
    Phoenix.PubSub.broadcast(Partners.PubSub, topic, message)
  end
end
