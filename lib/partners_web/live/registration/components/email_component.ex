defmodule PartnersWeb.Registration.Components.EmailComponent do
  use PartnersWeb, :live_component

  alias PartnersWeb.Registration.RegistrationLive
  alias Partners.Accounts.User

  import PartnersWeb.Registration.RegistrationLive, only: [assign_form: 2]

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center w-full px-4 h-full">
      <.form
        :let={f}
        for={@form}
        id={"#{@current_step}-form"}
        phx-change="validate"
        phx-submit="save"
        phx-target={@myself}
        class="w-full max-w-xl"
        phx-mounted={RegistrationLive.form_mounted_transition(@transition_direction)}
      >
        <div class="mb-4">
          <.input
            field={f[:email]}
            type="email"
            label="Email"
            placeholder="Enter your email"
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
            class={[
              "btn btn-ghost",
              if(@current_step == "email", do: "", else: "invisible")
            ]}
          >
            back
          </button>
          <button
            type="submit"
            phx-target={@myself}
            disabled={!@form.source.valid?}
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

  @impl true
  def handle_event("validate", %{"email" => email_params} = _params, socket) do
    socket =
      socket
      |> assign(messages: [])

    changeset = User.email_changeset(email_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  @impl true
  def handle_event("save", %{"email" => %{"email" => email}}, socket) do
    # Handle the save event, e.g., by calling an API or updating the database
    send(self(), {:proceed, :email, %{email: email}})
    {:noreply, socket}
  end
end
