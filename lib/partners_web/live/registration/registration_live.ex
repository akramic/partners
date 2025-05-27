defmodule PartnersWeb.Registration.RegistrationLive do
  use PartnersWeb, :live_view
  require Logger

  @steps %{
    1 => :new,
    2 => :email,
    3 => :username,
    4 => :phone,
    5 => :dob,
    6 => :gender,
    7 => :terms
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, live_action: :new, nav_direction: :forward)}
  end

  @impl true
  def handle_params(params, uri, socket) do
    Logger.info("🔔 RegistrationLive handle_params: #{inspect(params)}")

    socket =
      socket
      |> assign(
        live_action: Map.get(@steps, String.to_integer(params["current_step"] || "1"), :new)
      )
      |> assign(current_step: String.to_integer(params["current_step"] || "1"))

    Logger.info("🔔 RegistrationLive socket assigns: #{inspect(socket.assigns)}")
    {:noreply, socket}
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    current_step = socket.assigns.current_step || 1
    next_step = current_step + 1

    if next_step <= map_size(@steps) do
      socket =
        socket
        |> assign(:current_step, next_step)
        |> assign(:nav_direction, :forward)
        |> push_patch(to: ~p"/users/registration/#{next_step}")

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("prev_step", _params, socket) do
    current_step = socket.assigns.current_step || 1
    prev_step = current_step - 1

    if prev_step >= 1 do
      socket =
        socket
        |> assign(:current_step, prev_step)
        |> assign(:nav_direction, :backward)
        |> push_patch(to: ~p"/users/registration/#{prev_step}")

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("ready", _params, socket) do
    socket =
      socket
      |> assign(:current_step, 2)
      |> assign(:nav_direction, :forward)
      |> push_patch(to: ~p"/users/registration/#{2}")

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <PartnersWeb.Layouts.app current_scope={@current_scope} flash={@flash}>
      <PartnersWeb.Registration.RegistrationComponents.form_wrapper>
        <PartnersWeb.Registration.RegistrationComponents.render_form {assigns} />
      </PartnersWeb.Registration.RegistrationComponents.form_wrapper>
    </PartnersWeb.Layouts.app>
    """
  end
end
