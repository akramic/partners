defmodule PartnersWeb.AuthChannel do
  use PartnersWeb, :channel

  require Logger

  @impl true
  def join("auth:" <> req_user_id, _payload, socket = %{assigns: %{user_id: user_id}}) do
    if req_user_id == to_string(user_id) do
      IO.inspect("#{req_user_id} JOINED AUTH CHANNEL")
      {:ok, socket}
    else
      Logger.error("#{__MODULE__} failed #{req_user_id} != #{user_id}")
      {:error, %{reason: "unauthorized"}}
    end
  end
end
