defmodule PartnersWeb.Registration.RegistrationLive do
  use PartnersWeb, :live_view
  require Logger

  alias PartnersWeb.Registration.Step

  @steps [
    %Step{name: "start", prev: nil, next: "email"},
    %Step{name: "email", prev: "start", next: "username"},
    %Step{name: "username", prev: "email", next: "gender"},
    %Step{name: "gender", prev: "username", next: "dob"},
    %Step{name: "dob", prev: "gender", next: "telephone"},
    %Step{name: "telephone", prev: "dob", next: "terms"},
    %Step{name: "terms", prev: "telephone", next: nil}
  ]

  @impl true
  def mount(_params, _session, socket) do
    first_step = List.first(@steps)
    total_steps = length(@steps)

    socket =
      socket
      |> assign(
        steps: tl(@steps),
        step: 1,
        current_step: hd(@steps).name,
        total_steps: total_steps,
        progress: first_step,
        form_params: %{}
      )

    {:ok, assign_mount_transition_direction(socket, "forward")}
  end

  @impl true
  def handle_params(_unsigned_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:proceed, input_name, %{} = form}, socket) do
    params = %{
      input_name => Map.get(form, input_name)
    }

    socket =
      socket
      |> assign_mount_transition_direction("forward")
      |> assign(:form_params, Map.merge(socket.assigns.form_params, params))
      |> assign_step(:next)

    {:noreply, socket}
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
    <PartnersWeb.Layouts.app current_scope={@current_scope} flash={@flash}>
      <div class="overflow-x-hidden overflow-y-hidden w-full relative">
        <.progress_indicator
          :if={@current_step !== "start"}
          current_step={@current_step}
          form_params={@form_params}
          steps={@steps}
        />
        <PartnersWeb.Registration.RegistrationComponents.render {assigns} />
      </div>
    </PartnersWeb.Layouts.app>
    """
  end

  def progress_indicator(assigns) do
    ~H"""
    <nav aria-label="Progress" class="flex items-center justify-center w-full my-10">
      <ol role="list" class="flex items-center">
        <li :for={step <- @steps} class={["relative", step.name !== "terms" && "pr-8 sm:pr-20"]}>
          <div class="absolute inset-0 flex items-center" aria-hidden="true">
            <%!-- The edge color between nodes --%>
            <div class={[
              "h-0.5 w-full",
              (is_completed_step?(step, @form_params) && "bg-indigo-600") || "bg-gray-200"
            ]}>
            </div>
          </div>
          <%= if is_completed_step?(step,@form_params ) && step.name !== @current_step do %>
            <a
              href="#"
              class="relative flex size-8 items-center justify-center rounded-full bg-indigo-600 hover:bg-indigo-900"
            >
              <svg
                class="size-4 text-white"
                viewBox="0 0 20 20"
                fill="currentColor"
                aria-hidden="true"
                data-slot="icon"
              >
                <path
                  fill-rule="evenodd"
                  d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z"
                  clip-rule="evenodd"
                />
              </svg>
              <span class="sr-only">{step.name}</span>
            </a>
          <% end %>

          <%= if step.name == @current_step do %>
            <a
              href="#"
              class="relative flex size-8 items-center justify-center rounded-full border-2 border-indigo-600 bg-white"
              aria-current="step"
            >
              <span class="size-2.5 rounded-full bg-indigo-600" aria-hidden="true"></span>
              <span class="sr-only">{step.name}</span>
            </a>
          <% end %>

          <%= if step.name !== @current_step and not is_completed_step?(step, @form_params) do %>
            <a
              href="#"
              class="group relative flex size-8 items-center justify-center rounded-full border-2 border-gray-300 bg-white hover:border-gray-400"
            >
              <span
                class="size-2.5 rounded-full bg-transparent group-hover:bg-gray-300"
                aria-hidden="true"
              >
              </span>
              <span class="sr-only">{step.name}</span>
            </a>
          <% end %>
        </li>
      </ol>
    </nav>
    """
  end

  defp is_completed_step?(step, form_params) do
    Map.has_key?(form_params, String.to_atom(step.name))
  end

  def assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: socket.assigns.current_step)

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end

  def button_container_transition do
    %JS{}
    |> JS.transition(
      {"ease-out duration-[0.4s]", "translate-y-full", "translate-y-0"},
      time: 400
    )
  end

  def back_button_transition_push(current_step) do
    %JS{}
    |> JS.transition(
      {"ease-out duration-300", "translate-x-0", "translate-x-full"},
      time: 300,
      to: "##{current_step}-form"
    )
    |> JS.push("prev_step", value: %{direction: "backward"})
  end

  def form_mounted_transition(transition_direction) do
    %JS{}
    |> JS.transition(transition_direction,
      time: 300
    )
  end

  def show_tick?(atom, form) do
    form.source.valid? && form[atom].value && form[atom].value != ""
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
