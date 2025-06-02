defmodule PartnersWeb.Registration.RegistrationLive do
  use PartnersWeb, :live_view
  require Logger

  alias PartnersWeb.Registration.Step

  @steps [
    %Step{name: "start", prev: nil, next: "email"},
    %Step{name: "email", prev: "start", next: "username"},
    %Step{name: "username", prev: "email", next: "email"},
    %Step{name: "gender", prev: "username", next: "password"},
    %Step{name: "dob", prev: "gender", next: "terms"},
    %Step{name: "terms", prev: "dob", next: nil}
  ]

  @impl true
  def mount(_params, _session, socket) do
    first_step = List.first(@steps)
    total_steps = length(@steps)

    socket =
      socket
      |> assign(
        step: 1,
        current_step: hd(@steps).name,
        total_steps: total_steps,
        progress: first_step,
        form_params: %{}
      )
      |> assign_mount_transition_direction("forward")

    {:ok, socket}
  end

  @impl true
  def handle_params(_unsigned_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:proceed, input_name, data}, socket) do
    IO.inspect(input_name, label: "🔔 Received payload in handle_info", pretty: true)
    IO.inspect(data, label: "🔔 Received payload in handle_info", pretty: true)
    socket = assign_mount_transition_direction(socket, "forward")
    # def handle_info({:proceed, input_name, %{} = form}, socket) do
    # params = %{
    #   input_name => Map.get(form, input_name)
    # }

    # {:noreply,
    #  socket
    #  |> assign(:params, Map.merge(socket.assigns.params, params))
    #  |> assign_step(:next)}
    {:noreply, assign_step(socket, :next)}
  end

  @impl true
  def handle_event("prev_step", %{"direction" => direction}, socket) do
    socket =
      socket
      |> assign_mount_transition_direction(direction)
      |> assign_step(:prev)

    {:noreply, socket}
  end

  @impl true
  def handle_event("start", params, socket) do
    Logger.info("🔔 Starting registration with params: #{inspect(params)}")
    socket = assign_mount_transition_direction(socket, "forward")
    {:noreply, assign_step(socket, :next)}
  end

  # See if there is another step in the multi-step form and set it as the next step. If all steps are done, call the save(socket) function
  # to create the final changeset for registration of this new user account
  defp assign_step(socket, step) do
    # Check if there is another step to do and either assign it to the socket or this must be the final step and call the save function
    if new_step = Enum.find(@steps, &(&1.name == Map.get(socket.assigns.progress, step))) do
      socket
      |> assign(:step, assign_current_step(socket.assigns.step, step))
      |> assign(:progress, new_step)
      |> assign(:current_step, new_step.name)
    else
      save(socket)
    end
  end

  # Increments or decrements the current step
  defp assign_current_step(current_step, prev_or_next) do
    case prev_or_next do
      :prev -> current_step - 1
      :next -> current_step + 1
    end
  end

  defp save(socket) do
    socket
  end

  @impl true
  def render(assigns) do
    ~H"""
    <PartnersWeb.Layouts.app
      current_scope={@current_scope}
      transition_direction={@transition_direction}
      flash={@flash}
    >
      <pre>{inspect(@transition_direction, pretty: true)}</pre>
      <div class="overflow-x-hidden w-full relative">
        <PartnersWeb.Registration.RegistrationComponents.render {assigns} />
      </div>
    </PartnersWeb.Layouts.app>
    """
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
        raise ArgumentError,
              "Invalid transition direction: #{inspect(direction)}. Expected 'forward' or 'backward'."
    end
  end
end
