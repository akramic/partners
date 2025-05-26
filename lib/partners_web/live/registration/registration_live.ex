defmodule PartnersWeb.Registration.RegistrationLive do
  alias Swoosh.Email
  use PartnersWeb, :live_view
  require Logger

  alias PartnersWeb.CustomComponents.Layout

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(unsigned_params, uri, socket) do
    Logger.info("RegistrationLive handle_params: #{inspect(unsigned_params)}")
    Logger.info("RegistrationLive socket assigns: #{inspect(socket.assigns)}")
    {:noreply, socket}
  end

  @impl true
  def handle_event("ready", _params, socket) do
    socket =
      socket
      |> assign(:current_step, "email")
      |> assign(:live_action, :email)
      |> push_patch(to: ~p"/users/registration/email")

    # Handle form submission logic here
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <PartnersWeb.Layouts.app current_scope={@current_scope} flash={@flash}>
      <PartnersWeb.Registration.RegistrationComponents.render_form {assigns} />
    </PartnersWeb.Layouts.app>
    """
  end
end
