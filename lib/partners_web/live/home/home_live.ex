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
end
