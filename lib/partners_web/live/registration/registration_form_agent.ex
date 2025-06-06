defmodule PartnersWeb.Registration.RegistrationFormAgent do
  use GenServer
  require Logger

  # Run cleanup every 15 minutes
  @cleanup_interval :timer.minutes(15)
  # Session data expires after 24 hours
  @session_ttl :timer.hours(24)

  # Client API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_form_data(session_id) do
    GenServer.call(__MODULE__, {:get_form_data, session_id})
  end

  def update_form_data(session_id, form_data) do
    GenServer.cast(__MODULE__, {:update_form_data, session_id, form_data})
  end

  def delete_form_data(session_id) do
    GenServer.cast(__MODULE__, {:delete_form_data, session_id})
  end

  def touch_session(session_id) do
    # Update the last access timestamp for the session
    GenServer.cast(__MODULE__, {:touch_session, session_id})
  end

  # Server callbacks
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

  defp touch_session_data(state, session_id) do
    case Map.get(state, session_id) do
      nil ->
        state

      {form_data, _old_timestamp} ->
        Map.put(state, session_id, {form_data, System.os_time(:second)})
    end
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end
end
