defmodule PartnersWeb.Registration.Components.DobComponent do
  use PartnersWeb, :live_component

  alias PartnersWeb.Registration.RegistrationLive
  alias Partners.Access.Profiles.Profile

  import PartnersWeb.Registration.RegistrationLive, only: [assign_form: 2, show_tick?: 2]

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
        <div class="mb-4 relative">
          <div class="flex items-center">
            <div class="flex-grow">
              <.input
                field={f[:dob]}
                type="date"
                label="Date of Birth"
                placeholder="Select your date of birth"
                required
              />
            </div>
            <div
              :if={show_tick?(:dob, @form)}
              class="ml-4 text-success self-start mt-8"
            >
              <.icon name="hero-check-circle-solid" class="w-8 h-8" />
            </div>
          </div>
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
          {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
      end
  end
end
