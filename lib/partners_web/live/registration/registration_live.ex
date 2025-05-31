defmodule PartnersWeb.Registration.RegistrationLive do
  use PartnersWeb, :live_view
  require Logger

  @live_actions %{
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
    {:ok, assign(socket, live_action: @live_actions[1], current_step: 1)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    Logger.info("🔔 RegistrationLive handle_params: #{inspect(params)}")
    Logger.info("🔔 RegistrationLive socket assigns: #{inspect(socket.assigns)}")

    {:noreply, assign_step(socket, params)}
  end

  @impl true
  def handle_event("next_step", %{"direction" => "forward"}, socket) do
    socket =
      socket
      |> assign_mount_transition_direction("forward")
      |> push_patch(to: ~p"/users/registration/#{socket.assigns.current_step + 1}")

    {:noreply, socket}
  end

  @impl true
  def handle_event("prev_step", %{"direction" => "backward"}, socket) do
    socket =
      socket
      |> assign_mount_transition_direction("backward")
      |> push_patch(to: ~p"/users/registration/#{socket.assigns.current_step - 1}")

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <PartnersWeb.Layouts.app current_scope={@current_scope} flash={@flash}>
      <div class="overflow-x-hidden w-full relative">
        <PartnersWeb.Registration.RegistrationComponents.render_form {assigns} />
      </div>
    </PartnersWeb.Layouts.app>
    """
  end

  defp assign_step(socket, params) do
    current_step = String.to_integer(params["current_step"] || "1")

    assign(
      socket,
      live_action: Map.get(@live_actions, current_step, :new),
      current_step: current_step
    )
  end

  defp assign_mount_transition_direction(socket, direction) do
    case direction do
      "forward" ->
        assign(socket,
          transition_direction: {"ease-out duration-300", "translate-x-full", "translate-x-0"}
        )

      "backward" ->
        assign(socket,
          transition_direction: {"ease-out duration-300", "-translate-x-full", "translate-x-0"}
        )

      _ ->
        assign(socket,
          transition_direction: {"ease-out duration-300", "translate-x-0", "translate-x-0"}
        )
    end
  end
end
