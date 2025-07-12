defmodule PartnersWeb.Registration.Components.TermsComponent do
  use PartnersWeb, :live_component

  alias PartnersWeb.Registration.RegistrationLive
  alias Partners.Access.Profiles.Profile
  alias PartnersWeb.CustomComponents.{Atoms, Typography}

  import PartnersWeb.Registration.RegistrationLive, only: [assign_form: 2, show_tick?: 2]

  @doc """
  Renders the terms acceptance component with a centered checkbox layout.

  This component has a different layout from other registration components:
  - Checkbox and label are horizontally centered
  - Agreement text is displayed beneath the checkbox
  - Success checkmark appears to the right of the checkbox when terms are accepted

  This intentional layout difference emphasizes the importance of terms acceptance
  and places focus on the agreement text.
  """
  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-full w-full flex-col items-center justify-center px-4">
      <.form
        :let={f}
        for={@form}
        id={"#{@current_step}-form"}
        phx-change="validate"
        phx-submit="save"
        phx-target={@myself}
        class="w-full max-w-xl text-center"
        phx-mounted={RegistrationLive.form_mounted_transition(@transition_direction)}
      >
        <Atoms.kangaroo_dialogue_left>
          <Typography.p_xs class="text-balance">
            Please agree to the boring legal stuff!
          </Typography.p_xs>
        </Atoms.kangaroo_dialogue_left>
        <div class="relative mb-4">
          <div class="flex flex-col items-center">
            <div class="flex w-full items-center justify-center">
              <div class="flex-shrink">
                <.input
                  field={f[:terms]}
                  type="checkbox"
                  label="I agree to terms of membership"
                  required
                  autofocus
                />
              </div>
              <div :if={show_tick?(:terms, @form)} class="text-success ml-2">
                <.icon name="hero-check-circle-solid" class="h-8 w-8" />
              </div>
            </div>
            <div class="mt-2 text-center text-sm text-gray-600">
              By checking this box, you agree to our
              <a href="/terms" class="text-blue-600 hover:underline">Terms of Service</a>
              and <a href="/privacy" class="text-blue-600 hover:underline">Privacy Policy</a>.
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
            class={["btn btn-ghost ", if(@current_step == "email", do: "invisible", else: "")]}
          >
            <.icon name="hero-arrow-left" class="mr-2 h-4 w-4" /> back
          </button>

          <button type="submit" disabled={!@form.source.valid?} class="btn btn-primary">
            Create Account <.icon name="hero-arrow-right" class="ml-2 h-4 w-4" />
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    # Check if we have existing form params for terms acceptance
    params =
      if Map.has_key?(assigns, :form_params) && Map.has_key?(assigns.form_params, :terms) do
        %{"terms" => false}
      else
        # Default to unchecked
        %{}
      end

    changeset = Profile.registration_terms_changeset(params)

    socket =
      socket
      |> assign(assigns)
      |> assign_form(changeset)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"terms" => terms_params} = _params, socket) do
    changeset = Profile.registration_terms_changeset(terms_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  @impl true
  def handle_event("save", %{"terms" => terms_params} = _params, socket) do
    result =
      Profile.registration_terms_changeset(terms_params)
      |> Ecto.Changeset.apply_action(:insert)

    case result do
      {:ok, record} ->
        send(self(), {:proceed, :terms, record})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, socket |> assign_form(changeset)}
    end
  end
end
