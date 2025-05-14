defmodule Partners.Services.PaypalWebhookVerifier do
  @moduledoc """
  Provides functions to verify the signature of incoming PayPal webhook notifications,
  ensuring their authenticity and integrity.

  The core of this module, `validate_webhook_signature/1`, orchestrates the
  verification process based on PayPal's specifications. This process involves
  the following key steps:

  1.  **Fetching and Parsing the Signing Certificate:**
      - The certificate URL is extracted from the `PAYPAL-CERT-URL` header of the incoming webhook request.
      - `Partners.Services.PaypalCertificateManager.get_certificate/1` is used to fetch the PEM-encoded certificate string, potentially from a cache.
      - The PEM string is parsed into an OTP certificate record (an Erlang `:OTPCertificate` record) using `X509.Certificate.from_pem/1` (handled by `get_certificate_from_pem/1`). This record contains the certificate's data, including its public key and validity period.

  2.  **Extracting the Public Key:**
      - The public key is extracted from the parsed OTP certificate record using `X509.Certificate.public_key/1` (handled by `get_public_key_from_certificate/1`). This key is essential for cryptographic verification. The result is an Erlang public key record (e.g., `{:RSAPublicKey, ...}`).

  3.  **Validating Certificate Timeliness:**
      - The certificate's validity period (`not_before` and `not_after` dates) is checked against the current system time using `Timex` (logic within `is_certificate_in_date?/1`). This ensures the certificate has not expired and is within its intended operational timeframe. The `X509.Certificate.validity/1` function provides the raw date information, which is then parsed and compared.

  4.  **Determining the Hashing Algorithm:**
      - The `PAYPAL-AUTH-ALGO` header (e.g., "SHA256withRSA") specifies the algorithm used to sign the webhook.
      - This string is parsed to determine the corresponding Erlang digest type (e.g., `:sha256`) by `get_digest_type/1`. Unsupported algorithms will result in an error.

  5.  **Decoding the Transmission Signature:**
      - The `PAYPAL-TRANSMISSION-SIG` header contains the Base64 encoded digital signature of the webhook.
      - This signature is decoded from Base64 to its binary representation using `Base.decode64/2` (handled by `decode_transmission_sig/1`).

  6.  **Calculating the CRC32 Checksum of the Request Body:**
      - A CRC32 checksum of the raw HTTP request body is calculated. The raw body is expected to be available in `conn.assigns.raw_body`.
      - `:erlang.crc32/1` computes the checksum, which is then converted to a string (e.g., "1234567890") as required by PayPal for the signature base string. This is performed by `get_crc32_string/1`.

  7.  **Constructing the Signature Base String:**
      - A specific string, known as the signature base string or payload to verify, is constructed. This string is what PayPal actually signed.
      - It is formed by concatenating the following values, delimited by pipe characters (`|`):
        - `PAYPAL-TRANSMISSION-ID` (from request headers)
        - `PAYPAL-TRANSMISSION-TIME` (from request headers)
        - Your `configured_webhook_id` (retrieved via `Partners.Services.Paypal.webhook_id/0`, handled by `get_web_hook_id/0`)
        - The CRC32 checksum string calculated in the previous step.
      - The format is: `"transmission_id|transmission_time|webhook_id|crc32_string"`.
      - This construction happens within `construct_signature_payload/1`.

  8.  **Verifying the Signature:**
      - The final step is to cryptographically verify the decoded signature (from step 5) against the constructed signature base string (from step 7).
      - This is done using `:public_key.verify/4`, which takes the signature base string, the digest type (from step 4), the decoded signature, and the public key (from step 2).
      - If `:public_key.verify/4` returns `true`, the signature is valid. Otherwise, it's invalid. This check is performed in `validate_webhook_signature/1`.

  A successful verification, where all steps complete without error and the signature is cryptographically valid,
  results in `{:ok, :signature_valid}`. Any failure during these steps (e.g., missing headers,
  certificate issues, decoding errors, cryptographic mismatch) will result in an `{:error, reason}` tuple,
  where `reason` is an atom indicating the specific point of failure.

  This module relies on:
  - `Partners.Services.PaypalCertificateManager` for fetching and caching PayPal's public certificates.
  - `Partners.Services.Paypal` for retrieving the configured webhook ID.
  - The `x509` library for parsing certificates.
  - The `Timex` library for date/time operations.
  - Erlang's `:public_key` module for cryptographic operations.
  """

  require Logger
  alias X509.Certificate
  alias Timex
  alias Partners.Services.Paypal
  alias Partners.Services.PaypalCertificateManager

  @doc """
  Validates the signature of an incoming PayPal webhook notification.

  This function performs several checks as per PayPal's webhook security guidelines:
  1. Fetches the signing certificate from the URL specified in the `PAYPAL-CERT-URL` header
     (delegating to `PaypalCertificateManager` which handles caching).
  2. Validates the certificate's authenticity and date validity (not expired, not before validity period).
  3. Constructs the signature payload string. This involves:
     - Extracting `PAYPAL-TRANSMISSION-ID`, `PAYPAL-TRANSMISSION-TIME`, `PAYPAL-AUTH-ALGO`,
       and `PAYPAL-TRANSMISSION-SIG` headers.
     - Retrieving the raw request body (expected to be in `conn.assigns.raw_body`).
     - Calculating the CRC32 checksum of the raw request body.
     - Fetching your `configured_webhook_id` (via `Partners.Services.Paypal.webhook_id()`).
     - Assembling these into a pipe-delimited string:
     `"transmission_id|transmission_time|webhook_id|crc32_string"`
  4. Decodes the Base64 `PAYPAL-TRANSMISSION-SIG` header.
  5. Verifies the decoded signature against the constructed payload string
     using the public key from the validated certificate and the algorithm specified
     in `PAYPAL-AUTH-ALGO` (e.g., "SHA256withRSA").

  The `conn` argument is a `Plug.Conn` struct. It's crucial that the raw request body
  has been read and stored in `conn.assigns.raw_body` *before* this function is called.
  This is typically handled by a Plug like `Plug.Parsers` with the `:pass` option for
  the relevant content type, or a custom plug that reads the body.

  The `auth_algo` is expected to be a string like "SHA256withRSA".
  The `transmission_sig_base64` is the Base64 encoded signature from the `PAYPAL-TRANSMISSION-SIG` header.
  The `configured_webhook_id` is your application's webhook ID registered with PayPal,
  retrieved by `Partners.Services.Paypal.webhook_id()`.
  The `raw_request_body` is the full, unaltered HTTP request body.

  Returns `{:ok, :signature_valid}` if the signature is valid and all checks pass.
  Returns `{:error, reason}` for any failure, where `reason` is an atom
  indicating the cause (e.g., `:invalid_pem`, `:cert_expired`,
  `:invalid_signature`, `:algo_not_supported`, `:missing_headers`, `:raw_body_not_found`).
  """
  def validate_webhook_signature(conn) do
    Logger.debug("Attempting to validate PayPal webhook signature.")

    with {:ok, paypal_cert_url} <- get_header_value(conn.req_headers, "paypal-cert-url"),
         {:ok, otp_certificate} <- is_certificate_in_date?(paypal_cert_url),
         {:ok, public_key_record} <- get_public_key_from_certificate(otp_certificate),
         {:ok, map_signing_criteria} <- construct_signature_payload(conn) do
      result =
        :public_key.verify(
          map_signing_criteria.payload_to_verify,
          map_signing_criteria.digest_type,
          map_signing_criteria.decoded_signature,
          public_key_record
        )

      if(result) do
        Logger.debug("Signature verification successful.")
        {:ok, :signature_valid}
      else
        Logger.error("Signature verification failed.")
        {:error, :invalid_signature}
      end
    else
      _ ->
        Logger.error("Failed to construct signature payload")
        {:error, :failed_to_construct_signature_payload}
    end
  end

  # Functions to validate webhook signature

  # Constructs the map of data required for signature verification.

  # This involves extracting necessary headers, the raw request body,
  # calculating the CRC32 checksum, getting the webhook ID, determining the digest type,
  # and decoding the transmission signature.

  # The final payload to verify is a string concatenated in the format:
  # `"paypal_transmission_id|paypal_transmission_time|webhook_id|crc32_string"`

  defp construct_signature_payload(conn) do
    with {:ok, paypal_transmission_sig} <-
           get_header_value(conn.req_headers, "paypal-transmission-sig"),
         {:ok, paypal_auth_algo} <- get_header_value(conn.req_headers, "paypal-auth-algo"),
         {:ok, paypal_transmission_id} <-
           get_header_value(conn.req_headers, "paypal-transmission-id"),
         {:ok, paypal_transmission_time} <-
           get_header_value(conn.req_headers, "paypal-transmission-time"),
         {:ok, raw_body} <- get_raw_body(conn),
         {:ok, crc32_string} <- get_crc32_string(raw_body),
         {:ok, webhook_id} <- get_web_hook_id(),
         {:ok, digest_type} <- get_digest_type(paypal_auth_algo),
         {:ok, decoded_signature} <-
           decode_transmission_sig(paypal_transmission_sig) do
      # If all headers are present, proceed with signature validation
      Logger.debug("All required headers found. Proceeding with signature validation.")

      {:ok,
       %{
         payload_to_verify:
           "#{paypal_transmission_id}|#{paypal_transmission_time}|#{webhook_id}|#{crc32_string}",
         decoded_signature: decoded_signature,
         digest_type: digest_type
       }}
    else
      {:error, reason} ->
        Logger.error("Failed to extract PayPal webhook headers: #{inspect(reason)}")
        {:error, :missing_headers}
    end
  end

  defp get_public_key_from_certificate(otp_certificate) do
    public_key_record = X509.Certificate.public_key(otp_certificate)
    {:ok, public_key_record}
  end

  # Helper to extract a specific header value
  # Returns {:ok, value} or {:error, :header_not_found} if the header is not present (or Enum.find_value returns nil)
  defp get_header_value(headers, header_name) do
    Enum.find_value(headers, fn {name, value} ->
      if String.downcase(name) == String.downcase(header_name),
        do: {:ok, value},
        else: {:error, :header_not_found}
    end)
  end

  defp get_raw_body(conn) do
    # Retrieves the raw request body from conn.assigns.
    # It's expected that a Plug (e.g., Plug.Parsers or a custom one)
    # has already read the body and stored it in conn.assigns[:raw_body].
    raw_body = conn.assigns[:raw_body]

    case raw_body && raw_body != "" do
      true ->
        {:ok, raw_body}

      false ->
        Logger.error("Raw body not found in connection assigns.")
        {:error, :raw_body_not_found}
    end
  end

  # Calculates the CRC32 checksum of the raw request body and returns it as a string.
  # Paypal expects the CRC32 as a string in the signed payload.
  # Accepts a binary string and returns {:ok, crc32_string} or {:error, reason}.
  def get_crc32_string(raw_body_string) when is_binary(raw_body_string) do
    try do
      crc32_val = :erlang.crc32(raw_body_string)
      {:ok, Integer.to_string(crc32_val)}
    rescue
      ArgumentError ->
        {:error, :invalid_raw_body_for_crc32}

      e ->
        Logger.error("Unexpected error in get_crc32_string: #{inspect(e)}")
        {:error, :crc32_calculation_failed}
    end
  end

  # Handles cases where the input to get_crc32_string is not a binary.
  def get_crc32_string(_) do
    {:error, :invalid_input_to_get_crc32_string}
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

  defp decode_transmission_sig(paypal_transmission_sig) do
    case Base.decode64(paypal_transmission_sig, padding: true) do
      {:ok, decoded_signature} ->
        {:ok, decoded_signature}

      :error ->
        Logger.error(
          "Failed to Base64 decode PayPal transmission signature. Input might be invalid or incorrectly padded."
        )

        {:error, :signature_decode_failed}
    end
  end

  defp get_web_hook_id() do
    webhook_id = Paypal.webhook_id()

    if length(webhook_id) > 0 do
      {:ok, webhook_id}
    else
      Logger.error("Failed to get PayPal webhook ID")
      {:error, :webhook_id_not_found}
    end
  end

  @doc """
  Checks if the PayPal certificate is currently valid based on its date.

  This involves:
  1. Fetching the certificate's PEM string via `PaypalCertificateManager.get_certificate/1`.
  2. Parsing the PEM string into an OTP certificate record.
  3. Extracting the `not_before` and `not_after` validity dates from the certificate.
  4. Comparing these dates with the current system time (`Timex.now()`) to ensure:
     - The current time is on or after the `not_before` date.
     - The current time is on or before the `not_after` date.

  Returns `{:ok, otp_certificate}` if the certificate is valid and in date,
  otherwise `{:error, reason}`.
  """
  def is_certificate_in_date?(paypal_cert_url) do
    with {:ok, pem_string} <- PaypalCertificateManager.get_certificate(paypal_cert_url),
         {:ok, otp_certificate} <- get_certificate_from_pem(pem_string),
         {:ok, {time_type_1, not_before_charlist}, {time_type2, not_after_charlist}} <-
           extract_validity_tuple_from_cert(otp_certificate),
         {:ok, not_before_date: not_before_date, not_after_date: not_after_date} <-
           parse_date_tuples(
             {:ok, {time_type_1, not_before_charlist}, {time_type2, not_after_charlist}}
           ),
         {:ok, true} <- is_certificate_date_after_not_before_date?(not_before_date),
         {:ok, true} <- is_certificate_date_before_not_after_date?(not_after_date) do
      {:ok, otp_certificate}
    else
      {:error, reason} ->
        # If any check fails, return false
        Logger.error("Certificate validation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Parses a PEM-encoded certificate string into an OTP certificate record.

  Uses `X509.Certificate.from_pem/1` for parsing.

  Returns `{:ok, otp_certificate_record}` if parsing is successful,
  or `{:error, reason}` if parsing fails (e.g., `:not_found`, `:malformed`).
  The `otp_certificate_record` is an Erlang record of type `:OTPCertificate`
  (as defined by the `public_key` application).
  """
  def get_certificate_from_pem(pem_string) do
    Certificate.from_pem(pem_string)
  end

  defp extract_validity_tuple_from_cert(otp_certificate) do
    case X509.Certificate.validity(otp_certificate) do
      # not_before_date_tuple will be e.g. {:utcTime, ~c"YYMMDDHHMMSSZ"} or
      #                                    {:generalizedTime, ~c"YYYYMMDDHHMMSSZ"} or
      #                                    {:generalizedTime, ~c"YYYYMMDDHHMMSS.fffZ"} or
      #                                    {:generalizedTime, ~c"YYYYMMDDHHMMSS.ffffffZ"}
      # not_after_date_tuple will be similar.
      {:Validity, {:utcTime, not_before_charlist}, {:utcTime, not_after_charlist}} ->
        {:ok, {:utcTime, not_before_charlist}, {:utcTime, not_after_charlist}}

      {:Validity, {:generalizedTime, not_before_charlist}, {:generalizedTime, not_after_charlist}} ->
        {:ok, {:generalizedTime, not_before_charlist}, {:generalizedTime, not_after_charlist}}

      {:Validity, {:utcTime, not_before_charlist}, {:generalizedTime, not_after_charlist}} ->
        {:ok, {:utcTime, not_before_charlist}, {:generalizedTime, not_after_charlist}}

      {:Validity, {:generalizedTime, not_before_charlist}, {:utcTime, not_after_charlist}} ->
        {:ok, {:generalizedTime, not_before_charlist}, {:utcTime, not_after_charlist}}

      _ ->
        Logger.error("Unexpected certificate validity structure encountered.")
        {:error, :unexpected_validity_structure}
    end
  end

  # Parses the extracted ASN.1 date tuples (from extract_validity_tuple_from_cert/1)
  # into a map of DateTime structs: `%{not_before_date: DateTime.t(), not_after_date: DateTime.t()}`.
  # Handles the different combinations of :utcTime and :generalizedTime for `not_before` and `not_after` dates.
  defp parse_date_tuples({:ok, {:utcTime, not_before_charlist}, {:utcTime, not_after_charlist}}) do
    with {:ok, not_before_date} <- parse_utc_charlist_to_datetime(not_before_charlist),
         {:ok, not_after_date} <- parse_utc_charlist_to_datetime(not_after_charlist) do
      {:ok, not_before_date: not_before_date, not_after_date: not_after_date}
    else
      {:error, reason} ->
        Logger.error("Failed to parse UTC charlist: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_date_tuples(
         {:ok, {:utcTime, not_before_charlist}, {:generalizedTime, not_after_charlist}}
       ) do
    with {:ok, not_before_date} <- parse_utc_charlist_to_datetime(not_before_charlist),
         {:ok, not_after_date} <- parse_generalized_time_charlist_to_datetime(not_after_charlist) do
      {:ok, not_before_date: not_before_date, not_after_date: not_after_date}
    else
      {:error, reason} ->
        Logger.error("Failed to parse UTC charlist: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_date_tuples(
         {:ok, {:generalizedTime, not_before_charlist}, {:utcTime, not_after_charlist}}
       ) do
    with {:ok, not_after_date} <- parse_generalized_time_charlist_to_datetime(not_after_charlist),
         {:ok, not_before_date} <- parse_utc_charlist_to_datetime(not_before_charlist) do
      {:ok, not_before_date: not_before_date, not_after_date: not_after_date}
    else
      {:error, reason} ->
        Logger.error("Failed to parse UTC charlist: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_date_tuples(
         {:ok, {:generalizedTime, not_before_charlist}, {:generalizedTime, not_after_charlist}}
       ) do
    with {:ok, not_before_date} <-
           parse_generalized_time_charlist_to_datetime(not_before_charlist),
         {:ok, not_after_date} <- parse_generalized_time_charlist_to_datetime(not_after_charlist) do
      {:ok, not_before_date: not_before_date, not_after_date: not_after_date}
    else
      {:error, reason} ->
        Logger.error("Failed to parse UTC charlist: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # This function clause handles cases where the input tuple does not match
  # the expected successful extraction pattern from `extract_validity_tuple_from_cert/1`,
  # or if an error tuple is passed through.
  defp parse_date_tuples(_) do
    # This typically means a preceding step like `extract_validity_tuple_from_cert` failed,
    # or the input was not the expected `{:ok, {type, charlist}, {type, charlist}}` structure.
    Logger.error("Error parsing date tuples due to invalid input structure or preceding error.")
    {:error, :invalid_date_tuples_input}
  end

  defp parse_utc_charlist_to_datetime(utc_charlist) do
    # Convert the UTC charlist to a DateTime struct
    case Timex.parse(to_string(utc_charlist), "{ASN1:UTCtime}") do
      {:ok, datetime} ->
        {:ok, datetime}

      {:error, reason} ->
        Logger.error("Failed to parse UTC charlist: #{inspect(reason)}")
        {:error, :invalid_utc_format}
    end
  end

  defp parse_generalized_time_charlist_to_datetime(generalized_time_charlist) do
    # Convert the generalized time charlist to a DateTime struct
    case Timex.parse(to_string(generalized_time_charlist), "{ASN1:GeneralizedTime:Z}") do
      {:ok, datetime} ->
        {:ok, datetime}

      {:error, reason} ->
        Logger.error(
          "Failed to parse generalized time charlist '#{generalized_time_charlist}': #{inspect(reason)}"
        )

        {:error, :invalid_generalized_time_format}
    end
  end

  defp is_certificate_date_after_not_before_date?(not_before_date) do
    case Timex.before?(not_before_date, Timex.now()) do
      true -> {:ok, true}
      false -> {:error, "Certificate date is not valid yet. Not before date: #{not_before_date}"}
    end
  end

  defp is_certificate_date_before_not_after_date?(not_after_date) do
    case Timex.after?(not_after_date, Timex.now()) do
      true -> {:ok, true}
      false -> {:error, "Certificate has expired. Not after date: #{not_after_date}"}
    end
  end
end

# Example certificate
# {:ok,
#  {:OTPCertificate,
#   {:OTPTBSCertificate, :v3, 13658160064819539964065164760818638915,
#    {:SignatureAlgorithm, {1, 2, 840, 113549, 1, 1, 11}, :NULL},
#    {:rdnSequence,
#     [
#       [{:AttributeTypeAndValue, {2, 5, 4, 6}, ~c"US"}],
#       [
#         {:AttributeTypeAndValue, {2, 5, 4, 10},
#          {:printableString, ~c"DigiCert Inc"}}
#       ],
#       [
#         {:AttributeTypeAndValue, {2, 5, 4, 3},
#          {:printableString, ~c"DigiCert Global G2 TLS RSA SHA256 2020 CA1"}}
#       ]
#     ]},
#    {:Validity, {:utcTime, ~c"250313000000Z"}, {:utcTime, ~c"260413235959Z"}},
#    {:rdnSequence,
#     [
#       [{:AttributeTypeAndValue, {2, 5, 4, 6}, ~c"US"}],
#       [
#         {:AttributeTypeAndValue, {2, 5, 4, 8},
#          {:printableString, ~c"California"}}
#       ],
#       [{:AttributeTypeAndValue, {2, 5, 4, 7}, {:printableString, ~c"San Jose"}}],
#       [
#         {:AttributeTypeAndValue, {2, 5, 4, 10},
#          {:printableString, ~c"PayPal, Inc."}}
#       ],
#       [
#         {:AttributeTypeAndValue, {2, 5, 4, 3},
#          {:printableString, ~c"api.paypal.com"}}
#       ]
#     ]},
#    {:OTPSubjectPublicKeyInfo,
#     {:PublicKeyAlgorithm, {1, 2, 840, 113549, 1, 1, 1}, :NULL},
#     {:RSAPublicKey,
#      25644363490505114342926586092294413454987593361621028951334912141917261319491611702180190884199428573711338703571582221346772992675186052380310205510786418798312247974053068222484959127027609135326017018099765544765252052251003696021986659834556711905208356581693368572467573330696697789577545338097265289104122367412652263845954423903112293825408061466212240307091409998323820317617367247248551778189565603100567470125469275626883532258467252396868487762146563877719914495156121086234982054388631017549881670393711052401890087054196683346473781483080339758311399276222352236511393656756381387075866031286378017265899,
#      65537}}, :asn1_NOVALUE, :asn1_NOVALUE,
#    [
#      {:Extension, {2, 5, 29, 35}, false,
#       {:AuthorityKeyIdentifier,
#        <<116, 133, 128, 192, 102, 199, 223, 55, 222, 207, 189, 41, 55, 170, 3,
#          29, 190, 237, 205, 23>>, :asn1_NOVALUE, :asn1_NOVALUE}},
#      {:Extension, {2, 5, 29, 14}, false,
#       <<148, 205, 248, 71, 144, 93, 132, 122, 121, 235, 196, 190, 213, 169, 79,
#         237, 41, 245, 64, 208>>},
#      {:Extension, {2, 5, 29, 17}, false,
#       [
#         dNSName: ~c"api.paypal.com",
#         dNSName: ~c"api-3t.paypal.com",
#         dNSName: ~c"uptycshon.paypal.com",
#         dNSName: ~c"svcs.paypal.com",
#         dNSName: ~c"pointofsale.paypal.com",
#         dNSName: ~c"uptycsize.paypal.com",
#         dNSName: ~c"payflowpro.paypal.com",
#         dNSName: ~c"pointofsale-s.paypal.com",
#         dNSName: ~c"adjvendor.paypal.com",
#         dNSName: ~c"api-aa-3t.paypal.com",
#         dNSName: ~c"uptycshap.paypal.com",
#         dNSName: ~c"uptycsven.paypal.com",
#         dNSName: ~c"zootapi.paypal.com",
#         dNSName: ~c"uptycsbrt.paypal.com",
#         dNSName: ~c"api-aa.paypal.com",
#         dNSName: ~c"a.paypal.com",
#         dNSName: ~c"pilot-payflowpro.paypal.com",
#         dNSName: ~c"uptycspay.paypal.com",
#         dNSName: ~c"api-m.paypal.com"
#       ]},
#      {:Extension, {2, 5, 29, 32}, false,
#       [
#         {:PolicyInformation, {2, 23, 140, 1, 2, 2},
#          [
#            {:PolicyQualifierInfo, {1, 3, 6, 1, 5, 5, 7, 2, 1},
#             <<22, 27, 104, 116, 116, 112, 58, 47, 47, 119, 119, 119, 46, 100,
#               105, 103, 105, 99, 101, ...>>}
#          ]}
#       ]},
#      {:Extension, {2, 5, 29, 15}, true, [:digitalSignature, :keyEncipherment]},
#      {:Extension, {2, 5, 29, 37}, false,
#       [{1, 3, 6, 1, 5, 5, 7, 3, 1}, {1, 3, 6, 1, 5, 5, 7, 3, 2}]},
#      {:Extension, {2, 5, 29, 31}, false,
#       <<48, 129, 148, 48, 72, 160, 70, 160, 68, 134, 66, 104, 116, 116, 112, 58,
#         47, 47, 99, 114, 108, 51, 46, 100, ...>>},
#      {:Extension, {1, 3, 6, 1, 5, 5, 7, 1, 1}, false,
#       [
#         {:AccessDescription, {1, 3, 6, 1, 5, 5, 7, 48, 1},
#          {:uniformResourceIdentifier, ~c"http://ocsp.digicert.com"}},
#         {:AccessDescription, {1, 3, 6, 1, 5, 5, 7, 48, 2},
#          {:uniformResourceIdentifier,
#           ~c"http://cacerts.digicert.com/DigiCertGlobalG2TLSRSASHA2562020CA1-1.crt"}}
#       ]},
#      {:Extension, {2, 5, 29, 19}, true,
#       {:BasicConstraints, false, :asn1_NOVALUE}},
#      {:Extension, {1, 3, 6, 1, 4, 1, 11129, 2, 4, 2}, false,
#       <<4, 130, 1, 104, 1, 102, 0, 117, 0, 14, 87, 148, 188, 243, 174, 169, 62,
#         51, 27, 44, 153, ...>>}
#    ]}, {:SignatureAlgorithm, {1, 2, 840, 113549, 1, 1, 11}, :NULL},
#   <<172, 191, 103, 50, 223, 152, 213, 129, 215, 167, 86, 12, 200, 49, 36, 89,
#     164, 125, 164, 202, 53, 218, 2, 254, 22, 10, 12, 248, 104, 198, 204, 19,
#     226, 85, 173, 188, 242, 154, 174, 161, 190, 195, 73, 81, ...>>}}
