defmodule PartnersWeb.Registration.Components.TelephoneComponent do
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
                field={f[:telephone]}
                type="tel"
                label="Mobile Phone Number"
                placeholder="Enter your Australian mobile number"
                required
              />
              <.input field={f[:country_code]} type="hidden" value="AU" />
            </div>
            <div :if={show_tick?(:telephone, @form)} class="ml-4 text-success self-start mt-8">
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
    # Check if we have existing form params for telephone
    params =
      if Map.has_key?(assigns, :form_params) && Map.has_key?(assigns.form_params, :telephone) do
        %{
          "telephone" => assigns.form_params.telephone,
          "country_code" => Map.get(assigns.form_params, :country_code, "AU")
        }
      else
        %{}
      end

    changeset = Profile.registration_telephone_changeset(params)

    socket =
      socket
      |> assign(assigns)
      |> assign_form(changeset)

    {:ok, socket}
  end

  @impl true
  def handle_event(
        "validate",
        %{"telephone" => %{"country_code" => country_code, "telephone" => telephone}} = _params,
        socket
      ) do
    telephone_params = %{country_code: country_code, telephone: telephone}
    changeset = Profile.registration_telephone_changeset(telephone_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  @impl true
  def handle_event(
        "save",
        %{"telephone" => %{"country_code" => _country_code, "telephone" => telephone}} = _params,
        socket
      ) do
    # Add country code if not present (for Australian numbers)
    params = Map.put_new(telephone, "country_code", "AU")

    _changeset =
      Profile.registration_telephone_changeset(params)
      |> Ecto.Changeset.apply_action(:insert)
      |> case do
        {:ok, record} ->
          send(self(), {:proceed, :telephone, record})
          {:noreply, socket}

        {:error, changeset} ->
          {:noreply, socket |> assign_form(changeset)}
      end
  end
end
