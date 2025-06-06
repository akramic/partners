defmodule PartnersWeb.Registration.RegistrationFormAgent do
  @moduledoc """
  GenServer that manages persistent storage of registration form data.

  This module provides a supervised process that stores registration form data
  across page refreshes, allowing users to continue their registration even
  if they accidentally refresh the page or navigate away temporarily.

  Features:
  - Session-based storage of form data
  - Automatic cleanup of stale sessions after a configurable TTL
  - Timestamp tracking to maintain frequently accessed sessions
  - Thread-safe access to form data

  The GenServer maintains state as a map where:
  - Keys are session IDs
  - Values are tuples of {form_data, last_access_timestamp}
  """

  use GenServer
  require Logger

  # Run cleanup every 15 minutes
  @cleanup_interval :timer.minutes(15)
  # Session data expires after 24 hours
  @session_ttl :timer.hours(24)

  @doc """
  Starts the GenServer with an empty state map.

  This function is called by the supervision tree when the application starts.
  It registers the GenServer under the module name for easy access.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Retrieves the form data for the specified session ID.

  Returns the stored form data map for the given session, or an empty map
  if no data exists. Also updates the last access timestamp for the session.
  """
  def get_form_data(session_id) do
    GenServer.call(__MODULE__, {:get_form_data, session_id})
  end

  @doc """
  Updates the form data for the specified session ID.

  Stores the provided form_data map for the given session ID, replacing
  any existing data. Also updates the last access timestamp for the session.
  """
  def update_form_data(session_id, form_data) do
    GenServer.cast(__MODULE__, {:update_form_data, session_id, form_data})
  end

  @doc """
  Deletes the form data for the specified session ID.

  Completely removes all stored data for the given session ID,
  typically used when registration is completed or abandoned.
  """
  def delete_form_data(session_id) do
    GenServer.cast(__MODULE__, {:delete_form_data, session_id})
  end

  @doc """
  Updates the last access timestamp for the specified session ID.

  This prevents active sessions from being cleaned up by the
  periodic cleanup process, even if the user hasn't made any
  form changes. Called when a LiveView process terminates to
  ensure the session remains valid for when the user returns.
  """
  def touch_session(session_id) do
    # Update the last access timestamp for the session
    GenServer.cast(__MODULE__, {:touch_session, session_id})
  end

  # Server callbacks
  @doc """
  Initializes the GenServer state and starts the cleanup timer.

  Creates an empty map to store session data and schedules the first
  cleanup operation to run after the configured interval.
  """
  @impl true
  def init(_) do
    Logger.info(
      "🔔 Starting RegistrationFormAgent with cleanup interval of #{@cleanup_interval} ms"
    )

    # Start the cleanup timer
    schedule_cleanup()
    # State structure: %{session_id => {form_data, last_access_timestamp}}
    {:ok, %{}}
  end

  @doc """
  Handles the :get_form_data call to retrieve form data for a session.

  Looks up the form data for the given session_id in the state map.
  If found, returns the form_data and updates the last access timestamp.
  If not found, returns an empty map.
  """
  @impl true
  def handle_call({:get_form_data, session_id}, _from, state) do
    Logger.info("🔔 Fetching form data for session #{session_id}")

    case Map.get(state, session_id) do
      nil ->
        {:reply, %{}, state}

      {form_data, _timestamp} ->
        # Touch the session when accessed
        updated_state = touch_session_data(state, session_id)
        {:reply, form_data, updated_state}
    end
  end

  @doc """
  Handles various cast operations for session data management.

  Different message patterns:
  - {:update_form_data, session_id, form_data}: Updates the stored form data
    for the given session_id along with its timestamp
  - {:delete_form_data, session_id}: Removes all data for the given session_id
  - {:touch_session, session_id}: Updates only the timestamp for the session
    without modifying the form data, preventing premature cleanup
  """
  @impl true
  def handle_cast({:update_form_data, session_id, form_data}, state) do
    updated_state = Map.put(state, session_id, {form_data, System.os_time(:second)})
    {:noreply, updated_state}
  end

  @impl true
  def handle_cast({:delete_form_data, session_id}, state) do
    updated_state = Map.delete(state, session_id)
    {:noreply, updated_state}
  end

  @impl true
  def handle_cast({:touch_session, session_id}, state) do
    updated_state = touch_session_data(state, session_id)
    {:noreply, updated_state}
  end

  @doc """
  Handles the :cleanup message to remove expired sessions.

  Periodically called to clean up session data that hasn't been
  accessed within the configured TTL period. This prevents the
  state map from growing indefinitely with abandoned sessions.

  After cleanup, schedules the next cleanup operation.
  """
  @impl true
  def handle_info(:cleanup, state) do
    # Remove expired sessions
    now = System.os_time(:second)

    updated_state =
      Enum.reduce(state, %{}, fn {session_id, {data, timestamp}}, acc ->
        if now - timestamp > @session_ttl do
          Logger.debug("Removing expired registration form data for session #{session_id}")
          acc
        else
          Map.put(acc, session_id, {data, timestamp})
        end
      end)

    # Schedule the next cleanup

    schedule_cleanup()

    {:noreply, updated_state}
  end

  # Updates the timestamp for a session without changing its data.
  #
  # Helper function that takes the current state and a session_id,
  # updates the timestamp for that session, and returns the updated state.
  # If the session doesn't exist, returns the state unchanged.
  defp touch_session_data(state, session_id) do
    case Map.get(state, session_id) do
      nil ->
        state

      {form_data, _old_timestamp} ->
        Map.put(state, session_id, {form_data, System.os_time(:second)})
    end
  end

  # Schedules the next cleanup operation.
  #
  # Sends a delayed :cleanup message to the GenServer after the
  # configured cleanup interval has elapsed.
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end
end
