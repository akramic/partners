defmodule Partners.Services.Paypal do
  @moduledoc """
  Service module for PayPal API interactions.
  """

  require Logger

  # Private configuration access functions

  def api_url do
    Application.fetch_env!(:partners, __MODULE__)[:base_url] ||
      "https://api-m.sandbox.paypal.com"
  end

  def client_id do
    case Application.get_env(:partners, __MODULE__)[:client_id] do
      nil -> raise "PayPal client ID not configured"
      id -> id
    end
  end

  def client_secret do
    case Application.get_env(:partners, __MODULE__)[:secret] do
      nil -> raise "PayPal client secret not configured"
      secret -> secret
    end
  end

  def return_url do
    case Application.fetch_env!(:partners, __MODULE__)[:return_url] do
      nil -> raise "PayPal return URL not configured"
      url -> url
    end
  end

  def cancel_url do
    case Application.fetch_env!(:partners, __MODULE__)[:cancel_url] do
      nil -> raise "PayPal cancel URL not configured"
      url -> url
    end
  end
end
