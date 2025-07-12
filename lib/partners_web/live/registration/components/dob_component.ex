defmodule PartnersWeb.Registration.Components.DobComponent do
  use PartnersWeb, :live_component

  alias PartnersWeb.Registration.RegistrationLive
  alias Partners.Access.Profiles.Profile
  alias PartnersWeb.CustomComponents.{Atoms, Typography}

  import PartnersWeb.Registration.RegistrationLive, only: [assign_form: 2, show_tick?: 2]

  @min_age 21

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
            You must be 18 or over to join
          </Typography.p_xs>
        </Atoms.kangaroo_dialogue_left>
        <div class="relative mb-4">
          <div class="flex items-center">
            <div class="flex-grow">
              <.input
                field={f[:dob]}
                type="date"
                label="Date of Birth"
                placeholder="Select your date of birth"
                max={max_date()}
                required
                autofocus
              />
            </div>
            <div :if={show_tick?(:dob, @form)} class="text-success mt-8 ml-4 self-start">
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
    # Check if we have existing form params for DOB
    params =
      if Map.has_key?(assigns, :form_params) && Map.has_key?(assigns.form_params, :dob) do
        %{"dob" => assigns.form_params.dob}
      else
        %{}
      end

    changeset = Profile.registration_dob_changeset(params)

    socket =
      socket
      |> assign(assigns)
      |> assign_form(changeset)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"dob" => dob_params} = _params, socket) do
    socket =
      socket
      |> assign(messages: [])

    changeset = Profile.registration_dob_changeset(dob_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  @impl true
  def handle_event("save", %{"dob" => dob_params} = _params, socket) do
    _changeset =
      Profile.registration_dob_changeset(dob_params)
      |> Ecto.Changeset.apply_action(:insert)
      |> case do
        {:ok, record} ->
          send(self(), {:proceed, :dob, record})
          {:noreply, socket}

        {:error, changeset} ->
          {:noreply, socket |> assign_form(changeset)}
      end
  end

  defp max_date do
    # Set the maximum date to @min_age years ago from today
    # This ensures users must be at least @min_age years old
    Timex.now()
    |> Timex.shift(years: -@min_age)
    |> Timex.format!("{YYYY}-{0M}-{0D}")
  end
end
