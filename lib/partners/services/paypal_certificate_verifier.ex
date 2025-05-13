defmodule Partners.Services.PaypalCertificateVerifier do
  @moduledoc """
  Handles parsing and verification of PayPal's public certificate PEM strings,
  particularly for validating webhook signatures.
  This module is responsible for tasks like extracting expiry information,
  checking the validity of a certificate, and verifying cryptographic signatures.


  """

  # TODO:
  # 1. Decode pem_string:
  #    - Consider using the `x509` library: `X509.Certificate.from_pem(pem_string)`
  #    - This should give a certificate record/struct.
  #
  # 2. Extract public key from the parsed certificate.
  #    - e.g., `X509.Certificate.public_key(parsed_cert)`
  #
  # 3. Check certificate validity:
  #    - Expiry: Check `not_before` and `not_after` dates against current time.
  #      (Current date for reference: 11 May 2025)
  #      `X509.Certificate.validity(parsed_cert)` -> `%{not_before: ..., not_after: ...}`
  #    - Subject/Issuer: Optionally, verify if the certificate subject/issuer
  #      matches expected PayPal entities. This can be complex.
  #      `X509.Certificate.subject(parsed_cert)`, `X509.Certificate.issuer(parsed_cert)`
  #
  # 4. Parse `auth_algo` (e.g., "SHA256withRSA") to get the Erlang digest type (e.g., `:sha256`).
  #    - The signature scheme (RSA, ECDSA) is usually determined by the public key type.
  #    - A simple approach: String.starts_with?(auth_algo, "SHA256") -> :sha256, etc.
  #    - Handle unsupported algorithms (return `{:error, :algo_not_supported}`).
  #
  # 5. Decode `transmission_sig_base64` from Base64 to binary.
  #    - `Base.decode64(transmission_sig_base64, padding: true)`
  #    - Handle decoding errors (return `{:error, :signature_decode_failed}`).
  #
  # 6. Calculate CRC32 of `raw_request_body`.
  #    - `crc32_string = :erlang.crc32(raw_request_body) |> Integer.to_string()`
  #      (PayPal expects the CRC32 as a string in the signed payload)
  #
  # 7. Construct the signature base string (payload_to_verify):
  #    `payload_to_verify = "#{transmission_id}|#{transmission_time}|#{configured_webhook_id}|#{crc32_string}"`
  #
  # 8. Verify the signature:
  #    - `valid? = :public_key.verify(payload_to_verify, digest_type, decoded_signature, public_key)`
  #    - If not valid, return `{:error, :invalid_signature}`.
  #
  # Return `{:ok, true}` if all steps succeed.
  # Catch errors at each step and return appropriate `{:error, reason}` tuples.

  require Logger
  alias X509.Certificate
  alias Timex

  @doc """
  Validates the signature of an incoming PayPal webhook notification.

  This function performs several checks:
  1. Parses the provided PEM certificate string.
  2. Checks the certificate's validity (e.g., not expired, intended for PayPal).
  3. Constructs the signature payload string as per PayPal's specifications.
  4. Verifies the `transmission_sig_base64` against the constructed payload
     using the public key from the certificate and the `auth_algo`.

  The `auth_algo` is expected to be a string like "SHA256withRSA".
  The `transmission_sig_base64` is the Base64 encoded signature from the header.
  The `configured_webhook_id` is the ID of your webhook subscription in PayPal.
  The `raw_request_body` is the full, unaltered request body.

  Returns `{:ok, true}` if the signature is valid and all checks pass.
  Returns `{:error, reason}` for any failure, where `reason` is an atom
  indicating the cause (e.g., `:invalid_pem`, `:cert_expired`,
  `:invalid_signature`, `:algo_not_supported`).
  """
  def validate_webhook_signature(
        _pem_string,
        # Prefixed as not used yet
        _auth_algo,
        # Prefixed as not used yet
        _transmission_sig_base64,
        # Prefixed as not used yet
        _transmission_id,
        # Prefixed as not used yet
        _transmission_time,
        # Prefixed as not used yet
        _configured_webhook_id,
        # Prefixed as not used yet
        _raw_request_body
      ) do
    Logger.debug("Attempting to validate PayPal webhook signature.")
    # TODO
  end

  @doc """
  Check certifcate is valid
  """

  def is_certificate_in_date?(pem_string) do
    with {:ok, otp_certificate} <- get_certificate_from_pem(pem_string),
         {:ok, {time_type_1, not_before_charlist}, {time_type2, not_after_charlist}} <-
           extract_validity_tuple_from_cert(otp_certificate),
         {:ok, not_before_date: not_before_date, not_after_date: not_after_date} <-
           parse_date_tuples(
             {:ok, {time_type_1, not_before_charlist}, {time_type2, not_after_charlist}}
           ),
         {:ok, true} <- is_certificate_date_after_not_before_date?(not_before_date),
         {:ok, true} <- is_certificate_date_before_not_after_date?(not_after_date) do
      {:ok, true}
    else
      {:error, reason} ->
        # If any check fails, return false
        Logger.error("Certificate validation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Parses a PEM-encoded certificate string.

  Returns `{:ok, otp_certificate_record}` if parsing is successful,
  or `{:error, reason}` if parsing fails (e.g., `:not_found`, `:malformed`).
  The `otp_certificate_record` is an Erlang record of type `:OTPCertificate`.
  """
  def get_certificate_from_pem(pem_string) do
    Certificate.from_pem(pem_string)
  end

  defp get_public_key_from_cert(otp_certificate) do
    Certificate.public_key(otp_certificate)
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

  # Parses the extracted ASN.1 date tuples into a map of DateTime structs.
  # Handles the different combinations of :utcTime and :generalizedTime.
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

  # Handles error pass-through from previous extraction.
  defp parse_date_tuples(_) do
    # Implementation to be added
    # Likely just pass the error through
    Logger.error("Error parsing date tuples.")
    {:error, :invalid_date_tuples}
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
