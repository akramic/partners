defmodule PartnersWeb.Registration.Components.EmailComponent do
  use PartnersWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center w-full">
      <.form
        :let={f}
        for={@form}
        id="email-form"
        phx-change="validate"
        phx-submit="submit"
        class="w-full max-w-md"
        phx-mounted={
          %JS{}
          |> JS.transition(@transition_direction,
            time: 300
          )
        }
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
        <div class="flex items-center justify-between">
          <button type="submit" class="btn btn-primary">Submit</button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    IO.inspect(assigns, label: "🔔 EmailComponent update assigns", pretty: true)

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

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "email")

    if changeset.valid? do
      # Make API call to verify email
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
