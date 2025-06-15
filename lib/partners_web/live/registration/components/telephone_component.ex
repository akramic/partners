defmodule PartnersWeb.Registration.Components.TelephoneComponent do
  use PartnersWeb, :live_component

  require Logger

  alias PartnersWeb.Registration.RegistrationLive
  alias Partners.Access.Profiles.Profile
  alias Partners.Services.Sms
  alias PartnersWeb.CustomComponents.{Atoms, Typography}
  import PartnersWeb.Registration.RegistrationLive, only: [assign_form: 2, show_tick?: 2]

  @impl true
  def render(assigns) do
    ~H"""
    <div id="telephone_component" class="flex flex-col items-center justify-center w-full px-4 h-full">
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
            class="btn btn-ghost font-light"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> back
          </button>
          <%!-- We dispatch to the phx-change event and pattern match on the params --%>
          <button
            type="button"
            name="verify_telephone"
            phx-target={@myself}
            phx-click={JS.dispatch("change")}
            disabled={!@form.source.valid?}
            class="btn btn-primary"
          >
            Next <.icon name="hero-arrow-right" class="w-4 h-4 ml-2" />
          </button>
        </div>
      </.form>
      <Atoms.full_page_modal :if={@show_modal}>
        <div class="space-y-6 flex flex-col items-center justify-center w-full px-4 ">
          <Typography.p>
            Verify One Time Passcode
          </Typography.p>
          <Typography.p_xs>
            We have sent a one-time passcode (OTP) to your mobile phone number.
          </Typography.p_xs>

          <.form
            :let={otp}
            for={@otp_form}
            id="otp-form"
            phx-change="validate_otp"
            phx-submit="save"
            phx-target={@myself}
            class="w-full max-w-md"
            phx-mounted={RegistrationLive.form_mounted_transition(@transition_direction)}
          >
            <div class="mb-4 relative">
              <div class="flex items-center">
                <div class="flex-grow ">
                  <.input
                    field={otp[:otp]}
                    label="Enter Passcode"
                    placeholder="Enter your OTP"
                    required
                    type="text"
                  />
                </div>
                <div :if={show_tick?(:otp, @otp_form)} class="ml-4 text-success self-start mt-8">
                  <.icon name="hero-check-circle-solid" class="w-8 h-8" />
                </div>
              </div>
            </div>
            <div class="flex items-center justify-center w-full max-w-xl">
              <button type="submit" class="btn btn-primary">Verify Code</button>
            </div>
          </.form>

          <div class="flex flex-col justify-center items-center space-x-2">
            <button phx-click="request_otp_code" phx-target={@myself} class="btn btn-link">
              Request another code
            </button>
            <span
              phx-mounted={JS.transition("fade-in")}
              phx-remove={JS.transition("fade-out")}
              class={[
                "text-success text-[12px]",
                @code_sent && "opacity-100",
                !@code_sent && "opacity-0"
              ]}
            >
              <span class="flex justify-center items-end">
                New OTP sent <.icon name="hero-check" class="w-4 h-4 self-baseline ml-2" />
              </span>
            </span>
          </div>
        </div>
      </Atoms.full_page_modal>
    </div>
    """
  end

  @impl true
  def update(%{event: {:otp, otp}}, socket) do
    Logger.info("🔔 OTP received in update: #{otp}")

    # updated_socket = verify_otp(%{"otp" => otp}, socket)

    {:ok, socket}
  end

  @impl true
  def update(%{event: {:hide_code_sent, value}}, socket) do
    IO.inspect(value, label: "🔔 UPDATE RECEIVED")

    socket =
      socket
      |> assign(code_sent: false)

    {:ok, socket}
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
      |> assign(code_sent: false)
      |> assign(show_modal: false)
      |> assign(assigns)
      |> assign_form(changeset)

    {:ok, socket}
  end

  @impl true
  def handle_event(
        "request_otp_code",
        _params,
        socket
      ) do
    # Here we would typically send the OTP code to the user's phone number
    # For now, we just log it and show a modal

    send_update_after(self(), socket.assigns.myself, [event: {:hide_code_sent, true}], 2000)

    socket =
      socket
      |> assign(show_modal: true)
      |> assign(code_sent: true)

    {:noreply, socket}
  end

  # Called on the "validate" event when the user clicks the "Next" button
  # We have a valid input, so we can proceed to send the OTP code
  @impl true
  def handle_event(
        "validate",
        %{
          "_target" => ["verify_telephone"],
          "telephone" => %{"country_code" => country_code, "telephone" => telephone}
        } = _params,
        socket
      ) do
    Logger.info(
      "🔔 Clicked NEXT button Telephone number received in handle event validate: #{telephone}"
    )

    # send the OTP and save to socket
    otp_code = create_otp_code()
    Sms.send_otp_code(telephone, otp_code)

    otp_changeset = Profile.registration_otp_changeset(%{"stored_otp" => otp_code})

    socket =
      socket
      # Assign otp form with the changeset
      |> assign(stored_otp: otp_code)
      |> assign_otp_form(otp_changeset)
      |> assign(show_modal: true)

    telephone_params = %{country_code: country_code, telephone: telephone}
    changeset = Profile.registration_telephone_changeset(telephone_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
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
        "validate_otp",
        %{"otp" => %{"otp" => otp}} = otp_params,
        socket
      ) do
    Logger.info("🔔 OTP Code received in handle event validate_otp: #{inspect(otp_params)}")

    changeset =
      Profile.registration_otp_changeset(%{
        "stored_otp" => socket.assigns.stored_otp,
        "otp" => otp
      })

    {:noreply, assign_otp_form(socket, Map.put(changeset, :action, :validate))}
  end

  @impl true
  def handle_event(
        "save",
        %{"otp" => %{"otp" => otp}} = _otp_params,
        socket
      ) do
    Logger.info("🔔 Validated OTP Code received in handle event save: #{otp}")
    IO.inspect(socket.assigns.form.params, label: "🔔 Socket Form State")
    # socket.assigns.form.params are %{"country_code" => "AU", "telephone" => "0421774826"}
    params =
      socket.assigns.form.params
      |> Map.put_new("otp", otp)
      |> Map.put_new("stored_otp", socket.assigns.stored_otp)
      |> IO.inspect(label: "🔔 Params to be sent")

    case verify_telephone_and_otp(params) do
      {:ok, record} ->
        # Handle successful verification
        handle_successful_verification(socket, record)

      {:error, changeset} ->
        # Handle failed verification
        handle_changeset_error(socket, changeset)
    end
  end

  defp assign_otp_form(socket, %Ecto.Changeset{} = changeset) do
    otp_form = to_form(changeset, as: :otp)

    if changeset.valid? do
      assign(socket, otp_form: otp_form, check_errors: false)
    else
      assign(socket, otp_form: otp_form)
    end
  end

  defp create_otp_code do
    Enum.random(100_000..999_999)
    |> Integer.to_string()
  end

  defp verify_telephone_and_otp(params) do
    params
    |> Profile.registration_telephone_changeset()
    |> Profile.registration_otp_changeset(params)
    |> Ecto.Changeset.apply_action(:insert)
  end

  defp handle_successful_verification(socket, record) do
    Logger.info("🔔 OTP verification successful: #{inspect(record)}")
    send(self(), {:proceed, :telephone, record})
    {:noreply, assign(socket, show_modal: false)}
  end

  defp handle_changeset_error(socket, changeset) do
    Logger.error("❌ OTP verification failed: #{inspect(changeset)}")

    {:noreply, assign_form(socket, changeset) |> assign(show_modal: false)}
  end
end
