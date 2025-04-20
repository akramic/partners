defmodule PartnersWeb.Home.HomeLive do
  use PartnersWeb, :live_view

  alias PartnersWeb.CustomComponents.{Typography, Layout}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Home")
      |> assign_new(:current_scope, fn -> %{} end)

    # |> put_flash(:success, "Welcome to Phoenix LiveView!")

    {:ok, socket}
  end

  @impl true
  def handle_event("get_api_key", %{}, socket) do
    # Handle the event to get the API key here
    socket =
      socket
      |> push_event("get_api_key", %{
        api_key: get_api_key()
      })

    {:noreply, socket}
  end


 @impl true
  def handle_event("ip_registry_data", %{ "data" => data}, socket) do
    IO.inspect(data)
    {:noreply, socket}
  end




  defp get_api_key(), do: Application.get_env(:partners, :ip_registry_api_key)
end
