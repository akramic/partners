defmodule PartnersWeb.Registration.RegistrationLive do
  @moduledoc """
  LiveView module that handles the multi-step registration flow.

  This module manages the entire user registration process, including:
  - Tracking progress through multiple registration steps
  - Persisting form data between steps
  - Restoring fo          <%!-- Step label --%>
          <div class="text-center w-full mt-[clamp(0.25rem,0.8vw,0.5rem)]">
            <p
              class={[
                "uppercase inline-block",
                (step.name == @current_step || is_completed_step?(step, @form_params)) && "text-base-content/70",
                !(step.name == @current_step || is_completed_step?(step, @form_params)) && "text-base-content/50"
              ]}
              style="font-size: clamp(0.5625rem, 1.2vw, 0.625rem);"
            >
              {step.name}
            </p>
          </div>after page refreshes
  - Managing transitions between steps
  - Rendering appropriate form components for each step

  The registration flow uses a GenServer (RegistrationFormAgent) to persist
  form data across page refreshes, ensuring users don't lose progress.
  """

  use PartnersWeb, :live_view
  require Logger

  alias PartnersWeb.Registration.Step
  alias PartnersWeb.Registration.RegistrationFormAgent

  @steps [
    %Step{name: "start", prev: nil, next: "email", index: 0},
    %Step{name: "email", prev: "start", next: "username", index: 1},
    %Step{name: "username", prev: "email", next: "gender", index: 2},
    %Step{name: "gender", prev: "username", next: "dob", index: 3},
    %Step{name: "dob", prev: "gender", next: "telephone", index: 4},
    %Step{name: "telephone", prev: "dob", next: "terms", index: 5},
    %Step{name: "terms", prev: "telephone", next: nil, index: 6}
  ]

  @doc """
  Initializes the LiveView when it's first rendered.

  Retrieves the form data from the RegistrationFormAgent based on the session ID,
  determines the appropriate step to show based on previously completed steps,
  and sets up the initial socket assigns.
  """
  @impl true
  def mount(_params, %{"_csrf_token" => user_token} = session, socket) do
    Logger.info("🔔 Mounting RegistrationLive with session: #{inspect(session)}")
    session_id = Map.get(session, user_token)
    form_params = get_agent_data(session_id)

    # Find the appropriate step based on form data
    current_step = determine_current_step(form_params)

    socket =
      socket
      |> assign(
        steps: tl(@steps),
        # +1 for 1-indexed UI display
        step: current_step.index + 1,
        current_step: current_step.name,
        total_steps: length(@steps),
        progress: current_step,
        form_params: form_params,
        session_id: session_id
      )

    {:ok, assign_mount_transition_direction(socket, "forward")}
  end

  # Determines which step to show based on the user's completed form data.
  #
  # Analyzes the form_params map to find all completed steps, then identifies
  # the most recently completed step by its index. Returns the next step after
  # the last completed step, or the first step if no steps are completed.
  #
  # Uses a with expression to handle the sequential data transformations and
  # early returns for edge cases.
  defp determine_current_step(form_params) do
    with form_params when map_size(form_params) > 0 <- form_params,
         completed_step_names =
           form_params |> Map.keys() |> Enum.map(&Atom.to_string/1) |> MapSet.new(),
         true <- not Enum.empty?(completed_step_names),
         completed_steps =
           Enum.filter(@steps, fn step -> MapSet.member?(completed_step_names, step.name) end),
         true <- not Enum.empty?(completed_steps),
         last_completed = Enum.max_by(completed_steps, & &1.index),
         next_index = last_completed.index + 1,
         next_step when not is_nil(next_step) <-
           Enum.find(@steps, fn step -> step.index == next_index end) do
      # Found the next step after the last completed one
      next_step
    else
      # No form params, empty keys, or no completed steps - start at beginning
      _ -> List.first(@steps)
    end
  end

  @doc """
  Handles URL parameters when the page loads or parameters change.

  Currently passes through without modifications as parameter handling
  is not implemented for this LiveView.
  """
  @impl true
  def handle_params(_unsigned_params, _uri, socket) do
    {:noreply, socket}
  end

  @doc """
  Handles LiveView info events.

  Multiple implementations exist for different event types:

  - {:proceed, input_name, form} - Sent when a step component completes. Updates the form_params
    with the new data from the current step, persists it to the RegistrationFormAgent, and
    advances to the next step.

  - {:disconnected, _} - Triggered when the user's browser disconnects from the LiveView.
    Does not delete the session immediately as the user might just be refreshing the page.
    The TTL mechanism in the RegistrationFormAgent handles cleanup if needed.
  """
  @impl true
  def handle_info({:proceed, input_name, %{} = form}, socket) do
    params = %{
      input_name => Map.get(form, input_name)
    }

    updated_form_params = Map.merge(socket.assigns.form_params, params)
    # Update the form data in the agent
    RegistrationFormAgent.update_form_data(socket.assigns.session_id, updated_form_params)

    socket =
      socket
      |> assign_mount_transition_direction("forward")
      |> assign(:form_params, updated_form_params)
      |> assign_step(:next)

    {:noreply, socket}
  end

  # Called when the LiveView client disconnects
  @impl true
  def handle_info({:disconnected, _}, socket) do
    # We don't delete immediately, as the user might just be refreshing
    # The TTL mechanism will handle cleanup if they don't come back
    {:noreply, socket}
  end

  # Handle the event from client to get the IP registry api_key
  @impl true
  def handle_event("get_api_key", %{}, socket) do
    # Send the API key to the client
    {:noreply,
     push_event(socket, "get_api_key", %{
       api_key: get_api_key()
     })}
  end

  # Handle the event when the API call for IP data is successful and IP data received
  @impl true
  def handle_event(
        "ip_registry_data",
        %{"result" => ip_data},
        socket
      ) do
    # Create the updated form_params with the IP data
    updated_form_params = Map.merge(socket.assigns.form_params, %{ip_data: ip_data})
    # Update the form data in the agent
    RegistrationFormAgent.update_form_data(socket.assigns.session_id, updated_form_params)

    {:noreply, assign(socket, form_params: updated_form_params)}
  end

  @doc """
  Handles LiveView client events.

  Multiple implementations exist for different event types:

  - "prev_step" - Triggered when the user navigates to the previous step.
    Sets the transition direction to backward and moves to the previous step in the flow.

  - "start" - Triggered when beginning the registration process.
    Sets the transition direction to forward and moves to the first step in the registration flow.
  """
  @impl true
  def handle_event("prev_step", %{"direction" => direction}, socket) do
    socket =
      socket
      |> assign_mount_transition_direction(direction)
      |> assign_step(:prev)

    {:noreply, socket}
  end

  @impl true
  def handle_event("start", params, socket) do
    Logger.info("🔔 Starting registration with params: #{inspect(params)}")
    socket = assign_mount_transition_direction(socket, "forward")
    {:noreply, assign_step(socket, :next)}
  end

  # See if there is another step in the multi-step form and set it as the next step. If all steps are done, call the save(socket) function
  # to create the final changeset for registration of this new user account
  # Updates the socket with the next or previous step in the registration flow.
  #
  # Finds the next or previous step in the steps list based on the current step
  # and direction (prev or next). If there is no next step, calls the save/1 function
  # to complete the registration process.
  defp assign_step(socket, step) do
    # Check if there is another step to do and either assign it to the socket or this must be the final step and call the save function
    if new_step = Enum.find(@steps, &(&1.name == Map.get(socket.assigns.progress, step))) do
      socket
      |> assign(:step, assign_current_step(socket.assigns.step, step))
      |> assign(:progress, new_step)
      |> assign(:current_step, new_step.name)
    else
      save(socket)
    end
  end

  # Increments or decrements the current step index.
  # Takes the current step index and a direction (:prev or :next),
  # and returns the new step index. Used to determine which step
  # to display when navigating through the registration flow.

  defp assign_current_step(current_step, prev_or_next) do
    case prev_or_next do
      :prev -> current_step - 1
      :next -> current_step + 1
    end
  end

  # Handles the final step of the registration process.
  #
  # Called when all steps have been completed. Currently returns the socket
  # unchanged, but would typically create the user account and handle
  # the completed registration.
  defp save(socket) do
    Logger.info("🔔 Registration completed with params: #{inspect(socket.assigns.form_params)}")

    case Partners.Accounts.register_user(modify_params_for_cast_assoc(socket.assigns.form_params)) do
      {:ok, user} ->
        IO.inspect("🔔 Registration successful for user: #{inspect(user)}")
        # Registration successful, redirect to the next step or dashboard
        socket
        |> put_flash(:info, "Registration successful! Welcome, #{user.email}.")
        |> push_navigate(to: ~p"/subscriptions/start_trial/#{user.id}")

      {:error, changeset} ->
        # Handle registration error
        # Log the error changeset
        IO.inspect(changeset, label: "🔔 Registration error")

        # Determine which step has errors and find that step
        error_step = determine_error_step(changeset)
        error_step_map = Enum.find(@steps, &(&1.name == error_step))

        # Navigate to the error step and assign the form with errors
        socket
        |> put_flash(:error, "Sorry, we found an error.")
        |> assign(:step, error_step_map.index + 1)
        |> assign(:current_step, error_step_map.name)
        |> assign(:progress, error_step_map)

        # No need to assign a form from the changeset
    end
  end

  # Normalises params for cast_assoc. The profile params are embedded in the params map
  # We need to have key of profile giving profile => %{}
  # so we get user_params as a map with the following structure :
  #  %{ email => email, password => password, profile => %{}}

  defp modify_params_for_cast_assoc(form_params) do
    {user_params, profile_params} =
      form_params |> Map.split([:email])

    user_params
    |> Map.put(:profile, profile_params)
  end

  # Determine which step a user should be redirected to based on profile errors
  defp determine_error_step(%Ecto.Changeset{} = changeset) do
    # Get error fields from the profile changeset
    profile_changeset = changeset.changes[:profile]
    error_fields = if profile_changeset, do: Keyword.keys(profile_changeset.errors), else: []

    # Map error field to registration step
    cond do
      # Check each field and return the corresponding step
      Enum.member?(error_fields, :username) -> "username"
      Enum.member?(error_fields, :gender) -> "gender"
      Enum.member?(error_fields, :dob) -> "dob"
      Enum.member?(error_fields, :telephone) -> "telephone"
      Enum.member?(error_fields, :terms) -> "terms"
      # User-level errors (like email) or fallback
      true -> "email"
    end
  end

  @doc """
  Renders the LiveView template with the progress indicator and current step.

  Displays the appropriate registration component based on the current_step,
  along with the progress indicator showing completion status.
  """
  @impl true
  def render(assigns) do
    ~H"""
    <PartnersWeb.Layouts.app current_scope={@current_scope} flash={@flash}>
      <div class="overflow-x-hidden overflow-y-hidden w-full relative">
        <.progress_indicator
          :if={@current_step !== "start"}
          current_step={@current_step}
          form_params={@form_params}
          steps={@steps}
        />

        <PartnersWeb.Registration.RegistrationComponents.render {assigns} />
      </div>
    </PartnersWeb.Layouts.app>
    """
  end

  @doc """
  Renders the progress indicator component for the multi-step registration.

  Shows the user's progress through the registration steps with visual cues:
  - Completed steps show a checkmark
  - The current step shows a filled dot
  - Future steps show an empty dot

  Each step is color-coded and labeled to help users track their progress.
  """
  def progress_indicator(assigns) do
    ~H"""
    <nav aria-label="Progress" class="flex items-center justify-center w-full my-10 px-4">
      <ol role="list" class="flex items-center w-full max-w-xl">
        <li :for={step <- @steps} class="relative flex flex-col items-center flex-1">
          <%!-- The connecting line element --%>
          <%= if step.name !== "terms" do %>
            <div class="absolute left-1/2 top-[clamp(0.75rem,2.5vw,1rem)] w-full z-0">
              <div class={[
                "h-[1.5px] w-full",
                (is_completed_step?(step, @form_params) && "bg-primary") || "bg-base-content/30"
              ]}>
              </div>
            </div>
          <% end %>

          <%!-- Node container --%>
          <div class="flex justify-center w-full z-10">
            <%!-- Completed step --%>
            <%= if is_completed_step?(step,@form_params ) && step.name !== @current_step do %>
              <a
                href="#"
                class="relative flex items-center justify-center rounded-full bg-primary hover:bg-primary-focus"
                style="width: clamp(1.5rem, 5vw, 2rem); height: clamp(1.5rem, 5vw, 2rem);"
              >
                <svg
                  style="width: clamp(0.75rem, 2.5vw, 1rem); height: clamp(0.75rem, 2.5vw, 1rem);"
                  class="text-primary-content"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                  data-slot="icon"
                >
                  <path
                    fill-rule="evenodd"
                    d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z"
                    clip-rule="evenodd"
                  />
                </svg>
                <span class="sr-only">{step.name}</span>
              </a>
            <% end %>

            <%!-- Current step --%>
            <%= if step.name == @current_step do %>
              <a
                href="#"
                class="relative flex items-center justify-center rounded-full border-[1.5px] border-primary bg-base-100"
                style="width: clamp(1.5rem, 5vw, 2rem); height: clamp(1.5rem, 5vw, 2rem);"
                aria-current="step"
              >
                <span
                  class="rounded-full bg-primary"
                  style="width: clamp(0.5rem, 1.7vw, 0.625rem); height: clamp(0.5rem, 1.7vw, 0.625rem);"
                  aria-hidden="true"
                >
                </span>
                <span class="sr-only">{step.name}</span>
              </a>
            <% end %>

            <%!-- Future step --%>
            <%= if step.name !== @current_step and not is_completed_step?(step, @form_params) do %>
              <a
                href="#"
                class="group relative flex items-center justify-center rounded-full border-[1.5px] border-base-content/30 bg-base-100 hover:border-base-content/50"
                style="width: clamp(1.5rem, 5vw, 2rem); height: clamp(1.5rem, 5vw, 2rem);"
              >
                <span
                  class="rounded-full bg-base-content/10 group-hover:bg-base-content/20"
                  style="width: clamp(0.5rem, 1.7vw, 0.625rem); height: clamp(0.5rem, 1.7vw, 0.625rem);"
                  aria-hidden="true"
                >
                </span>
                <span class="sr-only">{step.name}</span>
              </a>
            <% end %>
          </div>

          <%!-- Step label --%>
          <div class="text-center w-full mt-[clamp(0.25rem,0.8vw,0.5rem)]">
            <p
              class="text-base-content/70 uppercase inline-block"
              style="font-size: clamp(0.5625rem, 1.2vw, 0.625rem);"
            >
              {step.name}
            </p>
          </div>
        </li>
      </ol>
    </nav>
    """
  end

  # Determines if a step has been completed based on the form_params.

  # A step is considered completed if there's an entry in the form_params map
  # with a key matching the step name.

  defp is_completed_step?(step, form_params) do
    Map.has_key?(form_params, String.to_atom(step.name))
  end

  @doc """
  Creates and assigns a form to the socket based on a changeset.

  If the changeset is valid, doesn't show error messages.
  If invalid, enables error display in the form.
  The form is named after the current step to ensure
  proper handling of form data across multiple steps in the registration flow.
  """

  def assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: socket.assigns.current_step)

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end

  @doc """
  Creates a JS transition for button containers.

  Defines a smooth animation for buttons appearing from the bottom of the screen.
  """
  def button_container_transition do
    %JS{}
    |> JS.transition(
      {"ease-out duration-[0.4s]", "translate-y-full", "translate-y-0"},
      time: 400
    )
  end

  @doc """
  Creates a JS transition and push event for the back button.

  Animates the form sliding out and pushes an event to go to the previous step
  with a 'backward' transition direction.
  """
  def back_button_transition_push(current_step) do
    %JS{}
    |> JS.transition(
      {"ease-out duration-300", "translate-x-0", "translate-x-full"},
      time: 300,
      to: "##{current_step}-form"
    )
    |> JS.push("prev_step", value: %{direction: "backward"})
  end

  @doc """
  Creates a JS transition for when a form is mounted.

  Applies the specified transition animation when a form component is rendered,
  creating smooth transitions between registration steps.
  """
  def form_mounted_transition(transition_direction) do
    %JS{}
    |> JS.transition(transition_direction,
      time: 300
    )
  end

  @doc """
  Determines if a checkmark indicator should be shown for a form field.

  Shows a checkmark when a field is valid and has a non-empty value.
  """
  def show_tick?(atom, form) do
    form.source.valid? && form[atom].value && form[atom].value != ""
  end

  # Assigns the appropriate CSS transition direction to the socket.
  #
  # Sets the transition direction for step animations based on whether
  # the user is moving forward or backward in the registration flow.
  defp assign_mount_transition_direction(socket, direction) do
    case direction do
      "forward" ->
        assign(socket,
          transition_direction: {"ease-out duration-300", "translate-x-full", "translate-x-0"}
        )

      "backward" ->
        assign(socket,
          transition_direction: {"ease-out duration-300", "-translate-x-full", "translate-x-0"}
        )

      _ ->
        raise ArgumentError,
              "Invalid transition direction: #{inspect(direction)}. Expected 'forward' or 'backward'."
    end
  end

  # Retrieves the form data for the given session ID from the RegistrationFormAgent.
  #
  # This is a wrapper around RegistrationFormAgent.get_form_data/1 to simplify
  # access to the GenServer from within the LiveView.
  defp get_agent_data(session_id) do
    RegistrationFormAgent.get_form_data(session_id)
  end

  defp get_api_key(), do: Application.get_env(:partners, :ip_registry_api_key)

  @doc """
  Callback that runs when the LiveView process is terminating.

  Updates the last access timestamp for the session in the RegistrationFormAgent
  to prevent premature cleanup of session data.
  """
  @impl true
  def terminate(_reason, socket) do
    if connected?(socket) do
      RegistrationFormAgent.touch_session(socket.assigns.session_id)
    end

    :ok
  end
end

# Registration error: #Ecto.Changeset<
#   action: :insert,
#   changes: %{
#     profile: #Ecto.Changeset<
#       action: :insert,
#       changes: %{
#         username: "akramic",
#         ip_data: %{
#           "carrier" => %{"mcc" => nil, "mnc" => nil, "name" => nil},
#           "company" => %{
#             "domain" => "aussiebb.com.au",
#             "name" => "Aussie Broadband",
#             "type" => "isp"
#           },
#           "connection" => %{
#             "asn" => 4764,
#             "domain" => "wideband.net.au",
#             "organization" => "Wideband Networks Pty LTD",
#             "route" => "117.20.68.0/22",
#             "type" => "isp"
#           },
#           "currency" => %{
#             "code" => "AUD",
#             "format" => %{
#               "decimal_separator" => ".",
#               "group_separator" => ",",
#               "negative" => %{"prefix" => "-$", "suffix" => ""},
#               "positive" => %{"prefix" => "$", "suffix" => ""}
#             },
#             "name" => "Australian Dollar",
#             "name_native" => "Australian Dollar",
#             "plural" => "Australian dollars",
#             "plural_native" => "Australian dollars",
#             "symbol" => "A$",
#             "symbol_native" => "$"
#           },
#           "hostname" => nil,
#           "ip" => "117.20.68.135",
#           "location" => %{
#             "city" => "Grange",
#             "continent" => %{"code" => "OC", "name" => "Oceania"},
#             "country" => %{
#               "area" => 7686850,
#               "borders" => [],
#               "calling_code" => "61",
#               "capital" => "Canberra",
#               "code" => "AU",
#               "flag" => %{
#                 "emoji" => "🇦🇺",
#                 "emoji_unicode" => "U+1F1E6 U+1F1FA",
#                 "emojitwo" => "https://cdn.ipregistry.co/flags/emojitwo/au.svg",
#                 "noto" => "https://cdn.ipregistry.co/flags/noto/au.png",
#                 "twemoji" => "https://cdn.ipregistry.co/flags/twemoji/au.svg",
#                 "wikimedia" => "https://cdn.ipregistry.co/flags/wikimedia/au.svg"
#               },
#               "languages" => [
#                 %{"code" => "en", "name" => "English", "native" => "English"}
#               ],
#               "name" => "Australia",
#               "population" => 26658948,
#               "population_density" => 3.47,
#               "tld" => ".au"
#             },
#             "in_eu" => false,
#             "language" => %{
#               "code" => "en",
#               "name" => "English",
#               "native" => "English"
#             },
#             "latitude" => -27.42317,
#             "longitude" => 153.01906,
#             "postal" => "4051",
#             "region" => %{"code" => "AU-QLD", "name" => "Queensland"}
#           },
#           "security" => %{
#             "is_abuser" => false,
#             "is_anonymous" => false,
#             "is_attacker" => false,
#             "is_bogon" => false,
#             "is_cloud_provider" => false,
#             "is_proxy" => false,
#             "is_relay" => false,
#             "is_threat" => false,
#             "is_tor" => false,
#             "is_tor_exit" => false,
#             "is_vpn" => false
#           },
#           "time_zone" => %{
#             "abbreviation" => "AEST",
#             "current_time" => "2025-06-08T09:54:15+10:00",
#             "id" => "Australia/Brisbane",
#             "in_daylight_saving" => false,
#             "name" => "Australian Eastern Standard Time",
#             "offset" => 36000
#           },
#           "type" => "IPv4",
#           "user_agent" => %{
#             "device" => %{
#               "brand" => nil,
#               "name" => "Linux Desktop",
#               "type" => "desktop"
#             },
#             "engine" => %{
#               "name" => "Blink",
#               "type" => "browser",
#               "version" => "137",
#               "version_major" => "137"
#             },
#             "header" => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36",
#             "name" => "Chrome",
#             "os" => %{"name" => "Linux", "type" => "desktop", "version" => nil},
#             "type" => "browser",
#             "version" => "137",
#             "version_major" => "137"
#           }
#         },
#         gender: :Male,
#         dob: ~D[1961-09-15],
#         telephone: "0421774826",
#         terms: true
#       },
#       errors: [some_value: {"can't be blank", [validation: :required]}],
#       data: #Partners.Access.Profiles.Profile<>,
#       valid?: false,
#       ...
#     >,
#     email: "michael.akram@gmail.com"
#   },
#   errors: [],
#   data: #Partners.Accounts.User<>,
#   valid?: false,
#   ...
# >
