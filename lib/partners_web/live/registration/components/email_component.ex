defmodule PartnersWeb.Registration.Components.EmailComponent do
  @moduledoc """
  LiveComponent for email validation and verification in the registration flow.

  Unlike other registration components, this component implements:

  1. **External API integration** - Validates emails through a third-party verification service
  2. **Advanced error handling** - Manages both standard validation and API-specific errors
  3. **Asynchronous loading state** - Shows a loader during external API calls
  4. **Multi-step validation** - Validates both format (client-side) and deliverability (API)

  This component serves as a bridge between user input and email verification services,
  ensuring that users provide valid, deliverable email addresses during registration.
  """

  require Logger
  use PartnersWeb, :live_component

  alias PartnersWeb.Registration.RegistrationLive
  alias Partners.Accounts.User
  alias Partners.Services.EmailVerification

  import PartnersWeb.Registration.RegistrationLive, only: [assign_form: 2, show_tick?: 2]

  @impl true
  def render(assigns) do
    ~H"""
    <div id="email_component" class="flex flex-col items-center justify-center w-full px-4 h-full">
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
              "btn btn-ghost font-light",
              if(@current_step == "email", do: "invisible", else: "")
            ]}
          >
            back
          </button>

          <%!-- We dispatch to the phx-change event and pattern match on the params --%>
          <button
            type="button"
            name="verify_email"
            phx-target={@myself}
            phx-click={JS.dispatch("change")}
            disabled={!@form.source.valid?}
            class="btn btn-primary"
          >
            Next <.icon name="hero-arrow-right" class="w-4 h-4 ml-2" />
          </button>
        </div>
      </.form>
      <PartnersWeb.CustomComponents.Atoms.full_page_loader :if={@show_loader} text="Verifying email" />
    </div>
    """
  end

  @impl true
  def update(%{event: {:verify_email, email}}, socket) do
    # Important: We need to get the updated socket from verify_email
    # and use that in our return value
    updated_socket = verify_email(%{"email" => email}, socket)

    {:ok, updated_socket}
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
      |> assign(show_loader: false)

    {:ok, socket}
  end

  @doc """

  handle_event multiple function heads.We match on the "validate" event to handle form validation.
  The "validate" event checks the email format and updates the form state accordingly.

  The validate function heads are designed to handle the verification of the email domain using
  the email verification API in services.

  The save event is triggered when the user submits the form. It sends the email to the parent process.

  """

  @impl true
  def handle_event(
        "validate",
        %{"_target" => ["verify_email"], "email" => %{"email" => email_params}} = _params,
        socket
      ) do
    send_update(self(), socket.assigns.myself, event: {:verify_email, email_params})

    socket =
      socket
      |> assign(show_loader: true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"email" => email_params} = _params, socket) do
    changeset = User.email_changeset(email_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  @doc """
  Verifies an email address through an external API and validates the result.

  ## Overview

  This function orchestrates the email verification workflow:
  1. Creates a User changeset from the email parameters
  2. Calls the external email verification API
  3. Applies verification rules to the changeset
  4. Validates the changeset against database constraints
  5. Handles success or various error conditions

  ## Parameters

    * `email_params` - Map with string keys containing the email to verify (format: `%{"email" => "user@example.com"}`)
    * `socket` - The LiveView socket with component assigns

  ## Returns

    On **success**:
    - Sets show_loader to false
    - Sends a :proceed message to the parent process
    - Returns the updated socket

    On **validation failure** (API or database):
    - Sets show_loader to false
    - Adds appropriate error messages to the changeset
    - Updates the form in the socket with the error changeset
    - Returns the updated socket

  ## Example

  ```elixir
  def handle_event("validate", %{"_target" => ["online"], "email" => email_params}, socket) do
    socket = assign(socket, show_loader: true)
    verify_email(email_params, socket)
  end
  ```
  """
  def verify_email(email_params, socket) do
    # Receives a validated %{"email" => email} as email_params
    # Create a base User.email_changeset with the email to be verified
    user_changeset =
      email_params
      |> User.email_changeset()
      |> Map.put(:action, :validate)

    # Call the email verification API
    with {:ok, response_map} <- EmailVerification.verify_email(email_params["email"]),
         # Apply email verification directly to the user changeset
         verified_changeset <-
           PartnersWeb.Registration.EmailVerifier.validate_email(user_changeset, response_map),
         # Check for database-level validations (like uniqueness)
         {:ok, record} <- Ecto.Changeset.apply_action(verified_changeset, :insert) do
      # Success path - email is valid and meets all criteria
      handle_successful_verification(socket, record)
    else
      # Handle the failure paths
      {:error, %Ecto.Changeset{} = changeset} ->
        handle_changeset_error(socket, changeset)

      {:error, reason} ->
        handle_api_error(socket, user_changeset, reason)
    end
  end

  # Handle successful email verification
  defp handle_successful_verification(socket, record) do
    send(self(), {:proceed, :email, record})
    assign(socket, show_loader: false)
  end

  # Handle database validation errors (e.g., uniqueness constraints)
  defp handle_changeset_error(socket, changeset) do
    socket
    |> assign(show_loader: false)
    |> assign_form(changeset)
  end

  # Handle API errors (e.g., network issues, service unavailable)
  defp handle_api_error(socket, user_changeset, reason) do
    Logger.error("❌ Email verification API failed: #{inspect(reason)}")

    changeset =
      user_changeset
      |> Ecto.Changeset.add_error(:email, "Unable to verify at this time: #{inspect(reason)}")

    socket
    |> assign(show_loader: false)
    |> assign_form(changeset)
  end
end
