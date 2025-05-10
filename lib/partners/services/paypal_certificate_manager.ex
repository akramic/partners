defmodule Partners.Services.PaypalCertificateManager do
  @moduledoc """
  Manages fetching and caching of PayPal's public certificates for webhook verification.
  Uses the x509 library to parse certificate details.
  """
  require Logger

  # The name for our Agent, to be started in application.ex
  @agent_name Partners.Services.PaypalCertificateManager.PaypalCertCache

  @type cert_url :: String.t()
  @type pem_string :: String.t()
  @type expires_at :: DateTime.t()
  # Cache stores: %{cert_url => %{pem: pem_string, expires_at: expires_at}}
  @type cache_entry :: %{pem: pem_string(), expires_at: expires_at()}

  @doc """
  Retrieves the PayPal certificate PEM string, fetching and caching it if necessary.
  """
  @spec get_certificate(cert_url :: cert_url()) :: {:ok, pem_string()} | {:error, atom()}
  def get_certificate(cert_url) do
    unless valid_paypal_domain?(cert_url) do
      Logger.error("Invalid PayPal certificate URL domain: #{cert_url}")
      {:error, :invalid_cert_url_domain}
    else
      case Agent.get(@agent_name, &Map.get(&1, cert_url)) do
        # Not found in cache
        nil ->
          Logger.info("Fetching PayPal certificate for URL (not in cache): #{cert_url}")
          fetch_and_cache_certificate(cert_url)

        # Found in cache, now check expiry
        %{} = cached_entry ->
          if not_expired?(cached_entry) do
            Logger.debug("Using cached PayPal certificate for URL: #{cert_url}")
            {:ok, cached_entry.pem}
          else
            Logger.info("Fetching/refreshing PayPal certificate for URL (expired): #{cert_url}")
            fetch_and_cache_certificate(cert_url)
          end
      end
    end
  end

  defp fetch_and_cache_certificate(cert_url) do
    case Req.get(cert_url) do
      {:ok, %{status: 200, body: pem_body}} ->
        case extract_expiry_from_pem_string(pem_body) do
          {:ok, expires_at} ->
            new_entry = %{pem: pem_body, expires_at: expires_at}
            Agent.update(@agent_name, &Map.put(&1, cert_url, new_entry))

            Logger.info(
              "Successfully fetched and cached PayPal certificate from #{cert_url}, expires: #{expires_at}"
            )

            {:ok, pem_body}

          {:error, reason} ->
            Logger.error(
              "Failed to parse expiry from PayPal certificate PEM from #{cert_url}: #{reason}"
            )

            {:error, :cert_parse_failed}
        end

      {:ok, %{status: status, body: body}} ->
        Logger.error(
          "Failed to fetch PayPal certificate from #{cert_url}. Status: #{status}, Body (partial): #{String.slice(body, 0, 200)}"
        )

        {:error, :fetch_failed_status}

      {:error, reason} ->
        Logger.error("Error fetching PayPal certificate from #{cert_url}: #{inspect(reason)}")
        {:error, :fetch_error}
    end
  end

  @spec extract_expiry_from_pem_string(pem_string :: pem_string()) ::
          {:ok, expires_at()} | {:error, atom()}
  defp extract_expiry_from_pem_string(pem_string) do
    try do
      case X509.Certificate.from_pem(pem_string) do
        {:ok, cert_data} ->
          # Log what we received from from_pem
          Logger.debug("X509.Certificate.from_pem/1 returned: #{inspect(cert_data)}")

          # Check if it's the struct or the Erlang record
          cond do
            is_map(cert_data) && Map.has_key?(cert_data, :tbs_certificate) ->
              # It's likely the struct as expected
              expires_at = cert_data.tbs_certificate.validity.not_after

              if is_struct(expires_at, DateTime) do
                {:ok, expires_at}
              else
                Logger.error(
                  "Parsed certificate 'not_after' (from struct) is not a DateTime struct: #{inspect(expires_at)}"
                )

                {:error, :invalid_expiry_format}
              end

            is_tuple(cert_data) and elem(cert_data, 0) == :OTPCertificate ->
              # It's the Erlang record, parse it using X509.Certificate functions.
              Logger.debug(
                "Received Erlang OTPCertificate record, parsing with X509.Certificate functions."
              )

              try do
                # Directly get the validity structure from the OTPCertificate
                validity_struct = X509.Certificate.validity(cert_data)

                # Pattern match to extract not_after from the validity structure
                # The validity_struct is expected to be: {:Validity, not_before_time, not_after_time}
                with {:Validity, _not_before, not_after_erlang_time} <- validity_struct do
                  # not_after_erlang_time is like {:utcTime, ~c"YYMMDDHHMMSSZ"}
                  # or {:generalTime, ~c"YYYYMMDDHHMMSSZ"}
                  case parse_erlang_time_to_datetime(not_after_erlang_time) do
                    {:ok, datetime_struct} ->
                      if is_struct(datetime_struct, DateTime) do
                        {:ok, datetime_struct}
                      else
                        Logger.error(
                          "parse_erlang_time_to_datetime did not return DateTime: #{inspect(datetime_struct)}"
                        )

                        {:error, :invalid_expiry_format_from_helper}
                      end

                    {:error, reason_time_parse} ->
                      Logger.error(
                        "Failed to parse Erlang time with X509.Time: #{inspect(reason_time_parse)}"
                      )

                      {:error, :x509_time_parse_failed}
                  end
                else
                  # Pattern match failed for validity_struct
                  _ ->
                    Logger.error(
                      "Unexpected structure for validity_struct: #{inspect(validity_struct)}"
                    )

                    {:error, :unexpected_validity_struct_format}
                end
              rescue
                e_record_parse ->
                  Logger.error(
                    "Error parsing Erlang certificate record fields: #{inspect(e_record_parse)}. Record was: #{inspect(cert_data)}"
                  )

                  {:error, :erlang_record_field_parse_error}
              end

            true ->
              Logger.error(
                "Unexpected data structure from X509.Certificate.from_pem: #{inspect(cert_data)}"
              )

              {:error, :unexpected_x509_cert_data_format}
          end

        {:error, reason} ->
          Logger.error("x509 library failed to parse PEM: #{inspect(reason)}")
          {:error, :x509_pem_parse_failed}
      end
    rescue
      e ->
        Logger.error("Exception during PEM parsing logic: #{inspect(e)}")
        {:error, :x509_logic_exception}
    end
  end

  @spec parse_erlang_time_to_datetime(erlang_time :: {:utcTime | :generalTime, charlist()}) ::
          {:ok, DateTime.t()} | {:error, atom()}
  defp parse_erlang_time_to_datetime({time_type, time_charlist})
       when time_type in [:utcTime, :generalTime] do
    time_string = List.to_string(time_charlist)

    # YYMMDDHHMMSSZ or YYYYMMDDHHMMSSZ
    # Ensure the Z is present for UTC
    unless String.ends_with?(time_string, "Z") do
      Logger.error("Erlang time string does not end with Z: #{time_string}")
      {:error, :invalid_erlang_time_format_no_z}
    else
      # Remove Z for parsing
      time_string_no_z = String.slice(time_string, 0, String.length(time_string) - 1)

      full_year_string =
        case {time_type, String.length(time_string_no_z)} do
          # utcTime: YYMMDDHHMMSS (12 chars)
          {:utcTime, 12} ->
            year_str = String.slice(time_string_no_z, 0, 2)
            month_str = String.slice(time_string_no_z, 2, 2)
            day_str = String.slice(time_string_no_z, 4, 2)
            hour_str = String.slice(time_string_no_z, 6, 2)
            min_str = String.slice(time_string_no_z, 8, 2)
            sec_str = String.slice(time_string_no_z, 10, 2)

            two_digit_year = String.to_integer(year_str)

            full_year =
              if two_digit_year >= 50, do: 1900 + two_digit_year, else: 2000 + two_digit_year

            "#{full_year}#{month_str}#{day_str}#{hour_str}#{min_str}#{sec_str}"

          # generalTime: YYYYMMDDHHMMSS (14 chars)
          {:generalTime, 14} ->
            time_string_no_z

          _ ->
            nil
        end

      if is_nil(full_year_string) do
        Logger.error("Invalid length for Erlang time string: #{time_string} (type: #{time_type})")
        {:error, :invalid_erlang_time_length}
      else
        year = String.to_integer(String.slice(full_year_string, 0, 4))
        month = String.to_integer(String.slice(full_year_string, 4, 2))
        day = String.to_integer(String.slice(full_year_string, 6, 2))
        hour = String.to_integer(String.slice(full_year_string, 8, 2))
        minute = String.to_integer(String.slice(full_year_string, 10, 2))
        second = String.to_integer(String.slice(full_year_string, 12, 2))

        case NaiveDateTime.new(year, month, day, hour, minute, second, {0, 0}) do
          {:ok, naive_datetime} ->
            case DateTime.from_naive(naive_datetime, "Etc/UTC") do
              {:ok, datetime} ->
                {:ok, datetime}

              {:error, reason_from_naive} ->
                Logger.error(
                  "Failed to convert NaiveDateTime to DateTime: #{inspect(reason_from_naive)}, from naive: #{inspect(naive_datetime)}"
                )

                {:error, :datetime_from_naive_failed}
            end

          {:error, reason_naive} ->
            Logger.error(
              "Failed to create NaiveDateTime: #{inspect(reason_naive)}, from YMDHMS: #{year}-#{month}-#{day} #{hour}:#{minute}:#{second}"
            )

            {:error, :naive_datetime_creation_failed}
        end
      end
    end
  rescue
    e ->
      Logger.error(
        "Exception in parse_erlang_time_to_datetime for #{inspect({time_type, time_charlist})}: #{inspect(e)}"
      )

      {:error, :datetime_parse_exception}
  end

  defp valid_paypal_domain?(url_string) do
    case URI.parse(url_string) do
      %URI{host: host} when is_binary(host) ->
        # Ensure the host is exactly "api.paypal.com" or "api.sandbox.paypal.com"
        # or ends with ".paypal.com" for broader cases if necessary, but strict is better for certs.
        # For now, let's be strict with known cert locations.
        # If PayPal serves certs from other subdomains, this list might need expansion.
        # Allow for potential future subdomains like api-m.paypal.com or api-m.sandbox.paypal.com
        host == "api.paypal.com" ||
          host == "api.sandbox.paypal.com" ||
          String.ends_with?(host, ".paypal.com") || String.ends_with?(host, ".sandbox.paypal.com")

      _ ->
        false
    end
  end

  defp not_expired?(%{expires_at: expires_at}) do
    # Add a small buffer (e.g., 1 hour) to consider a certificate "soon to expire" as effectively expired for proactive fetching.
    # For now, direct comparison.
    DateTime.compare(expires_at, DateTime.utc_now()) == :gt
  end

  # Public function to allow clearing the cache, useful for testing or forced refresh.
  @doc """
  Clears all cached PayPal certificates.
  """
  def clear_cache do
    Agent.update(@agent_name, fn _ -> %{} end)
    :ok
  end

  # Public function to inspect the cache content, useful for debugging.
  @doc """
  Returns the current state of the certificate cache.
  """
  def get_cache_state do
    Agent.get(@agent_name, & &1)
  end
end
