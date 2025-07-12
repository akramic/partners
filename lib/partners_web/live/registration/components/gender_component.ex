defmodule PartnersWeb.Registration.Components.GenderComponent do
  use PartnersWeb, :live_component

  alias PartnersWeb.Registration.RegistrationLive
  alias Partners.Access.Profiles.Profile
  alias PartnersWeb.CustomComponents.{Atoms, Typography}

  import PartnersWeb.Registration.RegistrationLive, only: [assign_form: 2, show_tick?: 2]

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-full w-full flex-col items-center justify-center px-4">
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
        <Atoms.kangaroo_dialogue_left>
          <Typography.p_xs class="text-balance">
            This is your birth gender.
          </Typography.p_xs>
        </Atoms.kangaroo_dialogue_left>
        <div class="relative mb-4">
          <div class="flex items-center">
            <div class="flex-grow">
              <.input
                field={f[:gender]}
                type="select"
                label="Gender"
                options={[Male: "Male", Female: "Female"]}
                prompt="Select your gender"
                required
                autofocus
              />
            </div>
            <div :if={show_tick?(:gender, @form)} class="text-success mt-8 ml-4 self-start">
              <.icon name="hero-check-circle-solid" class="h-8 w-8" />
            </div>
          </div>
        </div>

        <div
          phx-mounted={RegistrationLive.button_container_transition()}
          class="flex w-full max-w-xl items-center justify-between"
        >
          <button
            type="button"
            phx-click={RegistrationLive.back_button_transition_push(@current_step)}
            class="btn btn-ghost "
          >
            <.icon name="hero-arrow-left" class="mr-2 h-4 w-4" /> back
          </button>
          <button type="submit" disabled={!@form.source.valid?} class="btn btn-info text-white">
            Next <.icon name="hero-arrow-right" class="ml-2 h-4 w-4" />
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    # Check if we have existing form params for gender
    params =
      if Map.has_key?(assigns, :form_params) && Map.has_key?(assigns.form_params, :gender) do
        %{"gender" => assigns.form_params.gender}
      else
        %{}
      end

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
          {:noreply, socket |> assign_form(changeset)}
      end
  end
end
