defmodule Partners.Services.EmailVerification do
  @moduledoc """
  A service module for verifying email addresses using the Big Data API.
  This module provides functions to check if an email is valid, disposable, or from a known spammer domain.
  It uses the `Partners.Utils.DataTransformers` to convert API response keys from strings to atoms.

   Service provided by bigdatacloud.com

    Call
      https://api-bdc.net/data/email-verify?emailAddress=support@bigdatacloud.com&key=[YOUR API KEY]


    Example response is :
    {
    "inputData": "support@bigdatacloud.com",
    "isValid": true,
    "isSyntaxValid": true,
    "isMailServerDefined": true,
    "isKnownSpammerDomain": false,
    "isDisposable": false
    }

    The above is turned into a map like this:
    %{
      inputData: "support@bigdatacloud.com",
      isValid: true,
      isSyntaxValid: true,
      isMailServerDefined: true,
      isKnownSpammerDomain: false,
      isDisposable: false
    }

  by using the `Partners.Utils.DataTransformers.key_to_atom/1` function. Which is called like this:

    ```elixir
    Partners.Utils.DataTransformers.key_to_atom(response_body)
    ```


  """

  require Logger
 

  @doc """
  Fetches the email verification response from the API.
  Example response format:
  {:ok,
  %{
   "inputData" => "michael.akram@gmail.com.com",
   "isDisposable" => false,
   "isKnownSpammerDomain" => false,
   "isMailServerDefined" => true,
   "isSyntaxValid" => true,
   "isValid" => true
  }}"

  which is transformed to a map like this by using the `Partners.Utils.DataTransformers.key_to_atom/1` function:

  %{
    inputData: "michael.akram@gmail.com.com",
    isDisposable: false,
    isKnownSpammerDomain: false,
    isMailServerDefined: true,
    isSyntaxValid: true,
    isValid: true
  }

  This can now be used in Ecto changeset for validation by the caller.

  OR
  {:error, "API call failed: 404"}

  """

  def verify_email(email) when is_binary(email) do
    Logger.info("🔔 Verifying email: #{email}")

    response =
      Req.get!(build_url(email))

    case response do
      %Req.Response{status: 200, body: body} ->
        map = Partners.Utils.DataTransformers.key_to_atom(body)
        {:ok, map}

      %Req.Response{status: status} ->
        Logger.error("Failed to fetch email verification response: #{status}")
        {:error, "API call failed: #{status}"}
    end
  end

  defp api_key, do: Application.get_env(:partners, :big_data_api_key)
  defp base_url, do: "https://api-bdc.net/data/email-verify?"
  defp build_url(email), do: "#{base_url()}emailAddress=#{email}&key=#{api_key()}"
end
