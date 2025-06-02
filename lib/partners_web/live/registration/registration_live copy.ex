defmodule PartnersWeb.Registration.RegistrationLiveCopy do
  use PartnersWeb, :live_view
  require Logger

  alias PartnersWeb.Registration.RegistrationForm

  @live_actions %{
    1 => :new,
    2 => :email,
    3 => :username,
    4 => :dob,
    5 => :phone,
    6 => :gender,
    7 => :terms
  }

  @final_live_action :username

  @impl true
  def mount(_params, _session, socket) do
    socket = assign_form(socket, RegistrationForm.new())
    {:ok, assign(socket, live_action: @live_actions[1], current_step: 1)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, assign_step(socket, params)}
  end

  @impl true
  def handle_event("validate", %{"registration_form" => params}, socket) do
    changeset = RegistrationForm.validate(socket.assigns.form, params)
    IO.inspect(changeset, label: "🔔 Validate received changeset", pretty: true)
    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("submit", %{"registration_form" => params}, socket) do
    Logger.info(
      "🔔 Submit event received with live_action : #{inspect(socket.assigns.live_action)}"
    )

    changeset = RegistrationForm.validate(socket.assigns.form, params)

    socket =
      socket
      |> assign_mount_transition_direction("forward")
      |> push_patch(to: ~p"/users/registration/#{socket.assigns.current_step + 1}")

    IO.inspect(changeset, label: "🔔 Validate received changeset", pretty: true)
    {:noreply, assign_form(socket, changeset)}
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
        <PartnersWeb.Registration.RegistrationComponentsCopy.render_form {assigns} />
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

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: "registration_form"))
  end


end
