defmodule Partners.Services.Paypal.PaypalCertificateManager do
  @moduledoc """
  Manages fetching and caching of PayPal's public certificate PEM strings.
  It retrieves certificates from given URLs and stores them in an Agent-based cache.
  This module does NOT concern itself with parsing the certificate content (e.g., for expiry).
  """
  require Logger

  # The name for our Agent, to be started in application.ex
  @agent_name __MODULE__

  # Cache stores: %{cert_url => pem_string}

  @doc """
  Retrieves the PayPal certificate PEM string from a URL.
  It attempts to fetch from cache first. If not found, it fetches from the
  PayPal URL, caches it, and then returns it.
  """
  def get_certificate(cert_url) do
    unless valid_paypal_domain?(cert_url) do
      Logger.error("Invalid PayPal certificate URL domain: #{cert_url}")
      {:error, :invalid_cert_url_domain}
    else
      case Agent.get(@agent_name, &Map.get(&1, cert_url)) do
        nil ->
          Logger.info("Certificate not in cache. Fetching for URL: #{cert_url}")
          fetch_and_cache_certificate(cert_url)

        pem_string when is_binary(pem_string) ->
          Logger.debug("Using cached PayPal certificate for URL: #{cert_url}")
          {:ok, pem_string}
      end
    end
  end

  defp fetch_and_cache_certificate(cert_url) do
    case Req.get(cert_url) do
      {:ok, %Req.Response{status: 200, body: pem_body}} ->
        Agent.update(@agent_name, &Map.put(&1, cert_url, pem_body))
        Logger.info("Successfully fetched and cached PayPal certificate from #{cert_url}")
        {:ok, pem_body}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error(
          "Failed to fetch PayPal certificate from #{cert_url}. Status: #{status}, Body (partial): #{String.slice(body, 0, 200)}"
        )

        {:error, :fetch_failed_status}

      {:error, reason} ->
        Logger.error("Error fetching PayPal certificate from #{cert_url}: #{inspect(reason)}")
        {:error, :fetch_error}
    end
  end

  defp valid_paypal_domain?(url_string) do
    case URI.parse(url_string) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and is_binary(host) ->
        # Allow api.paypal.com, api.sandbox.paypal.com, and any subdomains of paypal.com or sandbox.paypal.com
        host == "api.paypal.com" ||
          host == "api.sandbox.paypal.com" ||
          String.ends_with?(host, ".paypal.com") ||
          String.ends_with?(host, ".sandbox.paypal.com")

      _ ->
        Logger.warning("Invalid URI or missing host for PayPal domain check: #{url_string}")
        false
    end
  end

  @doc """
  Clears all cached PayPal certificates.
  """
  def clear_cache do
    Agent.update(@agent_name, fn _ -> %{} end)
    Logger.info("PayPal certificate cache cleared.")
    :ok
  end

  @doc """
  Returns the current state of the certificate cache.
  Useful for debugging.
  """
  def get_cache_state do
    Agent.get(@agent_name, & &1)
  end
end
