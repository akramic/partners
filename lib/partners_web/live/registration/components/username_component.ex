defmodule PartnersWeb.Registration.Components.UsernameComponent do
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
            field={f[:username]}
            type="text"
            label="Username"
            placeholder="Enter your username"
            required
          />
        </div>
      </.form>
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
        <button type="submit" disabled={!@form.source.valid?} class="btn btn-primary">
          Next <.icon name="hero-arrow-right" class="w-4 h-4 ml-2" />
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    params = %{}
    changeset = Partners.Accounts.User.email_changeset(params)

    socket =
      socket
      |> assign(assigns)
      |> assign(messages: [])
      |> assign(show_modal: false)
      |> assign(trigger_submit: false, check_errors: false)
      |> assign_form(changeset)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"username" => username_params} = _params, socket) do
    socket =
      socket
      |> assign(messages: [])

    changeset = Profile.registration_username_changeset(username_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end
end
