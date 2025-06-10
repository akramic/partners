defmodule Partners.Services.Sms do
  @moduledoc """
  This module is responsible for sending mobile messages to users.

  Partners.Services.Sms.send_otp_code("+61421774826", "123456")
  or
  Partners.Services.Sms.send_otp_code("61421774826", "123456")
  or
  Partners.Services.Sms.send_otp_code("0421774826", "123456", "custom_ref")

  Example success response:
  {:ok,
  %{
   "results" => [
     %{
       "cost" => 1,
       "custom_ref" => "custom_ref",
       "message" => "Your OTP code is: 123456",
       "message_id" => "0c0f290e-86d9-414d-ae8c-9c7842f27224",
       "sender" => "61485900133",
       "status" => "success",
       "to" => "61421774826"
     }
   ],
   "status" => "complete",
   "total_cost" => 1
  }}

  """

  require Logger

  def send_otp_code(to_mobile_number, otp_code) do
    with {:ok, encoded_data} <- message_data(to_mobile_number, otp_code) do
      try do
        response =
          Req.post!(
            get_base_url(),
            body: encoded_data,
            headers: [
              {"Authorization", "Basic #{encode_credentials()}"},
              {"Content-Type", "application/json"}
            ]
          )

        # The body is already decoded as JSON by default
        {:ok, response.body}
      rescue
        e ->
          Logger.error("❌ Failed to send OTP code: #{inspect(e)}")
          {:error, :sms_sending_failed}
      end
    end
  end

  # Uncomment this function if you want to use Finch instead of Req
  #  def send_otp_code(to_mobile_number, otp_code) do
  #   with {:ok, encoded_data} <- message_data(to_mobile_number, otp_code),
  #        {:ok, response} <-
  #          Finch.build(
  #            :post,
  #            get_base_url(),
  #            [
  #              {"Authorization", "Basic #{encode_credentials()}"},
  #              {"Content-Type", "application/json"}
  #            ],
  #            encoded_data
  #          )
  #          |> Finch.request(PartnersFinch),
  #        {:ok, response_map} <- Jason.decode(response.body) do
  #     {:ok, response_map}
  #   else
  #     err -> IO.inspect(err, label: "send ERROR")
  #   end
  # end

  # Private functions

  defp message_data(to_mobile_number, otp_code) do
    data = %{
      messages: [
        %{
          to: to_mobile_number,
          message: """
          Loving.Partners
          Passcode: #{otp_code}
          """,
          sender: get_sender_name(),
          custom_ref: to_mobile_number
        }
      ]
    }

    # Return {:ok, string} instead of iodata
    Jason.encode(data)
  end

  defp encode_credentials() do
    Base.encode64("#{get_username()}:#{get_password()}")
  end

  defp get_username(), do: Application.get_env(:partners, :mobile_messaging_api_username)
  defp get_password(), do: Application.get_env(:partners, :mobile_messaging_api_password)
  defp get_base_url(), do: Application.get_env(:partners, :mobile_messaging_api_base_url)
  defp get_sender_name(), do: Application.get_env(:partners, :mobile_messaging_api_sender_name)
end
