defmodule PartnersWeb.Registration.Components.UsernameComponent do
  use PartnersWeb, :live_component

  alias Partners.Access.Profiles.Profile

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center w-full px-4">
      <.form
        :let={f}
        for={@form}
        id={"#{@current_step}-form"}
        phx-submit="save"
        phx-change="validate"
        phx-target={@myself}
        class="w-full max-w-xl"
        phx-mounted={
          %JS{}
          |> JS.transition(@transition_direction,
            time: 300
          )
        }
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
      <div class="flex items-center justify-between w-full max-w-xl">
        <button
          type="button"
          phx-click={
            %JS{}
            |> JS.transition(
              {"ease-out duration-300", "translate-x-0", "translate-x-full"},
              time: 300,
              to: "##{@current_step}-form"
            )
            |> JS.push("prev_step", value: %{direction: "backward"})
          }
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
      <pre>{inspect @form, pretty: true}</pre>
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

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "username")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
