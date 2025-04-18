defmodule PartnersWeb.Home.HomeLive do
  use PartnersWeb, :live_view

  alias PartnersWeb.CustomComponents.{Typography, Layout}

  @impl true
  def mount(_params, _session, socket) do
    # socket = put_flash(socket, :info, "Welcome to Phoenix LiveView!")
    {:ok, assign(socket, page_title: "Home")}
  end
end
