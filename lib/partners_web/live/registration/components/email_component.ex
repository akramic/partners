defmodule PartnersWeb.Registration.Components.EmailComponent do
  require Logger
  use PartnersWeb, :live_component

  alias PartnersWeb.Registration.RegistrationLive
  alias Partners.Accounts.User

  import PartnersWeb.Registration.RegistrationLive, only: [assign_form: 2, show_tick?: 2]

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center w-full px-4 h-full">
      <.form
        :let={f}
        for={@form}
        id={"#{@current_step}-form"}
        phx-change="validate"
        phx-target={@myself}
        class="w-full max-w-xl"
        phx-mounted={RegistrationLive.form_mounted_transition(@transition_direction)}
      >
        <div class="mb-4 relative">
          <div class="flex items-center">
            <div class="flex-grow">
              <.input
                field={f[:email]}
                type="email"
                label="Email"
                placeholder="Enter your email"
                required
              />
            </div>
            <div :if={show_tick?(:email, @form)} class="ml-4 text-success self-start mt-8">
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
            class={[
              "btn btn-ghost",
              if(@current_step == "email", do: "invisible", else: "")
            ]}
          >
            back
          </button>

          <%!-- We dispatch to the phx-change event and pattern match on the params --%>
          <button
            type="button"
            name="online"
            phx-target={@myself}
            phx-click={JS.dispatch("change")}
            class="btn btn-primary"
          >
            Next <.icon name="hero-arrow-right" class="w-4 h-4 ml-2" />
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    # Check if we have existing form params for email
    params =
      if Map.has_key?(assigns, :form_params) && Map.has_key?(assigns.form_params, :email) do
        %{"email" => assigns.form_params.email}
      else
        %{}
      end

    changeset = Partners.Accounts.User.email_changeset(params)

    socket =
      socket
      |> assign(assigns)
      |> assign_form(changeset)

    {:ok, socket}
  end

  @doc """

  handle_event multiple function heads.We match on the "validate" event to handle form validation
  and the "save" event to handle form submission. The "validate" event checks the email format
  and updates the form state accordingly.

  The validate function heads are designed to handle the verification of the email domain using the external email verification API.

  """

  @impl true
  def handle_event("validate", %{"_target" => ["online"], "email" => %{"email" => email}}, socket) do
    Logger.info("🔔 Validating email with online target: #{inspect(email)}")
    push_flash(:info, "Validating email...")
    send(self(), {:proceed, :email, %{email: email}})
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"email" => email_params} = _params, socket) do
    socket =
      socket
      |> assign(messages: [])

    changeset = User.email_changeset(email_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end
end
