defmodule PartnersWeb.Registration.Components.GenderComponent do
  use PartnersWeb, :live_component

  alias PartnersWeb.Registration.RegistrationLive
  alias Partners.Access.Profiles.Profile

  import PartnersWeb.Registration.RegistrationLive, only: [assign_form: 2]

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center w-full px-4 h-full">
      <.form
        :let={f}
        for={@form}
        id={"#{@current_step}-form"}
        phx-submit="save"
        phx-change="validate"
        phx-target={@myself}
        class="w-full max-w-xl"
        phx-mounted={RegistrationLive.form_mounted_transition(@transition_direction)}
      >
        <div class="mb-4">
          <.input
            field={f[:gender]}
            type="select"
            label="Gender"
            options={[Male: "Male", Female: "Female"]}
            prompt="Select your gender"
            required
          />
        </div>

        <div
          phx-mounted={RegistrationLive.button_container_transition()}
          class="flex items-center justify-between w-full max-w-xl"
        >
          <button
            type="button"
            phx-click={RegistrationLive.back_button_transition_push(@current_step)}
            class="btn btn-ghost"
          >
            back
          </button>
          <button type="submit" disabled={!@form.source.valid?} class="btn btn-primary">
            Next <.icon name="hero-arrow-right" class="w-4 h-4 ml-2" />
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    params = %{}
    changeset = Profile.registration_gender_changeset(params)

    socket =
      socket
      |> assign(assigns)
      |> assign_form(changeset)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"gender" => gender_params} = _params, socket) do
    socket =
      socket
      |> assign(messages: [])

    changeset = Profile.registration_gender_changeset(gender_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  @impl true
  def handle_event("save", %{"gender" => gender_params} = _params, socket) do
    _changeset =
      Profile.registration_gender_changeset(gender_params)
      |> Ecto.Changeset.apply_action(:insert)
      |> case do
        {:ok, record} ->
          send(self(), {:proceed, :gender, record})
          {:noreply, socket}

        {:error, changeset} ->
          {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
      end
  end
end
