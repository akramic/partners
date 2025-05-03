defmodule Partners.Access.Demographics.Postcodes.PostcodesContext do
  @moduledoc """
  Context module for postcode-related operations.

  This module implements the ContextBehaviour interface specifically for
  postcode-related operations. It serves as a domain boundary for interactions
  with postcodes in the system.

  ## Architecture Overview

  The PostcodesContext is part of the application's layered architecture:

  1. **Web Layer** (LiveViews/Controllers) - Handles HTTP requests and UI interactions
  2. **Context Layer** (PostcodesContext) - Contains business logic and orchestration
  3. **Access Layer** (PostcodesAccess) - Manages data persistence operations
  4. **Schema Layer** (Postcode) - Defines the structure and validation rules

  This separation allows for:

  * **Single Responsibility** - Each layer has a clear, focused role
  * **Dependency Inversion** - Higher layers depend on abstractions, not implementations
  * **Testability** - Each layer can be tested in isolation
  * **Flexibility** - Implementation details can change without affecting clients

  ## Context Design Pattern Benefits

  Using the Context pattern with the Access layer abstraction provides:

  1. **Consistent Interface** - All domain operations follow the same pattern
  2. **Business Logic Encapsulation** - Rules are enforced at the context level
  3. **Simplified Client Code** - Web layer can focus on presentation concerns
  4. **Composable Operations** - Contexts can be combined for complex workflows
  5. **Clear Domain Boundaries** - Explicit separation between different concerns

  ## Usage Examples

  The PostcodesContext provides a consistent interface for all postcode operations,
  simplifying client code and enforcing business rules. Here are examples showing
  how to use this module in different contexts:

  ### Fetching Place Names for a Postal Code

  ```elixir
  # In a LiveView or controller handling location selection
  def handle_event("select_postcode", %{"postal_code" => postal_code}, socket) do
    case PostcodesContext.manage(%{postal_code: postal_code}, :place_names_for_postal_code) do
      {:ok, place_names} ->
        {:noreply, assign(socket, place_names: place_names, selected_postal_code: postal_code)}

      {:error, :no_places_found} ->
        {:noreply, assign(socket, place_names: [], selected_postal_code: postal_code)}
    end
  end
  ```

  ### Using Postcode Search in a Form

  ```elixir
  # In a LiveView or controller handling postcode search
  def handle_event("search_postcodes", %{"search" => %{"term" => term}}, socket) do
    case PostcodesContext.manage(%{search_term: term}, :search_postcodes) do
      {:ok, results} ->
        {:noreply, assign(socket, search_results: results)}

      {:error, :no_postcodes_found} ->
        {:noreply, assign(socket, search_results: [])}
    end
  end
  ```

  ### Profile Location Setup with Postcode Selection

  ```elixir
  # In a multi-step location setup process
  def handle_event("set_location", %{"postcode_id" => postcode_id}, socket) do
    # First get the place names for this postcode
    case PostcodesContext.manage(%{postcode_id: postcode_id}, :place_names_for_postcode_id) do
      {:ok, []} ->
        {:noreply, put_flash(socket, :error, "Selected postcode has no associated places")}

      {:ok, place_names} ->
        # Store the postcode_id and move to place name selection step
        {:noreply,
          socket
          |> assign(postcode_id: postcode_id, place_names: place_names)
          |> assign(step: :select_place_name)}

      {:error, :no_places_found} ->
        {:noreply, put_flash(socket, :error, "No places found for the selected postcode")}
    end
  end
  ```

  ### Loading All Postcodes

  ```elixir
  # In a LiveView or controller initializing a form with postcodes
  def mount(_params, _session, socket) do
    case PostcodesContext.manage(%{}, :list_all_postcodes) do
      {:ok, postcodes} ->
        {:ok, assign(socket, :postcodes, postcodes)}

      {:error, :no_postcodes_found} ->
        {:ok, assign(socket, :postcodes, [])}
    end
  end
  ```

  ### Integration with Profile Context

  The real power of the context pattern becomes apparent when composing multiple contexts:

  ```elixir
  # In a profile creation wizard LiveView
  def handle_event("finalize_location", %{"place_name" => place_name}, socket) do
    # Combine previously selected postcode with place name
    location_params = %{
      postcode_id: socket.assigns.postcode_id,
      place_name: place_name
    }

    # Update the user's profile with the new location
    case ProfilesContext.manage(
      %{profile: socket.assigns.profile, attrs: location_params},
      :update_profile_location
    ) do
      {:ok, updated_profile} ->
        {:noreply,
          socket
          |> assign(:profile, updated_profile)
          |> put_flash(:info, "Location updated successfully")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to update location")}
    end
  end
  ```

  ### Advanced Pattern: Context Composition

  Contexts can be composed for more complex operations that span multiple domains:

  ```elixir
  # In a service module handling user onboarding
  def complete_location_setup(user_id, postcode_id, place_name) do
    # First validate the postcode exists and has the selected place
    with {:ok, postcode} <- PostcodesContext.manage(%{postcode_id: postcode_id}, :load_postcode),
         true <- postcode.place_name == place_name || Enum.member?(postcode.place_names, place_name),
         {:ok, profile} <- ProfilesContext.manage(%{user_id: user_id}, :get_profile_by_user_id),
         {:ok, updated_profile} <- ProfilesContext.manage(
           %{
             profile: profile,
             attrs: %{
               postcode_id: postcode_id,
               place_name: place_name,
               geom: %Geo.Point{coordinates: {postcode.longitude, postcode.latitude}, srid: 4326}
             }
           },
           :update_profile_location
         ) do
      # If this is the first time setting location, maybe send a welcome notification
      if is_nil(profile.postcode_id) do
        NotificationsContext.manage(
          %{user_id: user_id, type: :location_completed},
          :create_notification
        )
      end

      # Return the updated profile
      {:ok, updated_profile}
    else
      false -> {:error, :invalid_place_name}
      {:error, reason} -> {:error, reason}
    end
  end
  ```

  These examples illustrate how the PostcodesContext module provides a flexible interface
  for working with postcode data in various scenarios, from simple lookups to
  integration with other contexts like profile management, while maintaining clear
  domain boundaries and separation of concerns.
  """
  @behaviour Partners.Access.Behaviour.ContextBehaviour

  require Logger
  alias Partners.Access.Demographics.Postcodes.PostcodesAccess

  # Use the access module directly
  @postcode_access PostcodesAccess

  @impl Partners.Access.Behaviour.ContextBehaviour
  @doc """
  Fetches all place names for a specified postal code.

  This operation retrieves distinct place names associated with a particular
  postal code, useful for location selection interfaces where users first
  select a postal code and then a specific place within that code.

  ## Parameters

    * `attrs` - Map containing the following keys:
      * `:postal_code` - The postal code string (e.g., "AB12 3CD")

  ## Returns

    * `{:ok, place_names}` - List of place name strings on success
    * `{:error, :no_places_found}` - If no places are found for the postal code

  ## Examples

      iex> PostcodesContext.manage(%{postal_code: "AB12 3CD"}, :place_names_for_postal_code)
      {:ok, ["Aberdeen", "Altens", "Cove Bay"]}
  """
  def manage(attrs, :place_names_for_postal_code) do
    %{postal_code: postal_code} = attrs

    # Use the filter function from the access behavior
    {_count, results} =
      @postcode_access.filter(
        %{
          postal_code: postal_code,
          select: [:place_name],
          order_by: :place_name
        },
        :postcode
      )

    place_names = Enum.map(results, & &1.place_name)

    if place_names == [] do
      {:error, :no_places_found}
    else
      {:ok, place_names}
    end
  end

  @impl Partners.Access.Behaviour.ContextBehaviour
  # Fetches all place names for a specified postcode ID.
  #
  # This operation retrieves place names associated with a postcode identified
  # by its database ID. It's typically used in multi-step forms where a user has
  # already selected a postcode from a list and now needs to specify a place.
  #
  # Parameters:
  #   * `attrs` - Map containing the following keys:
  #     * `:postcode_id` - The database ID of the postcode
  #
  # Returns:
  #   * `{:ok, place_names}` - List of place name strings on success
  #   * `{:error, :no_places_found}` - If no places are found for the postcode ID or if the postcode doesn't exist
  #
  # Examples:
  #
  #     iex> PostcodesContext.manage(%{postcode_id: 123}, :place_names_for_postcode_id)
  #     {:ok, ["Leith", "Edinburgh"]}
  def manage(attrs, :place_names_for_postcode_id) do
    %{postcode_id: postcode_id} = attrs

    # Use the load function from the access behavior
    case @postcode_access.load(%{id: postcode_id}, :postcode) do
      {:ok, postcode} when is_list(postcode) ->
        place_names = Enum.map(postcode, & &1.place_name)
        {:ok, place_names}

      {:ok, postcode} ->
        place_names = [postcode.place_name]
        {:ok, place_names}

      _ ->
        {:error, :no_places_found}
    end
  end

  @impl Partners.Access.Behaviour.ContextBehaviour
  # Searches for postcodes that match a search pattern.
  #
  # This operation performs a prefix search (LIKE query) for postcodes based
  # on a user-provided search term. It's typically used in autocomplete interfaces
  # or search forms to help users find their postcode.
  #
  # Parameters:
  #   * `attrs` - Map containing the following keys:
  #     * `:search_term` - The search string to match against postal codes
  #
  # Returns:
  #   * `{:ok, postcodes}` - List of postcode records matching the search term
  #   * `{:error, :no_postcodes_found}` - If no postcodes match the search term
  #
  # Examples:
  #
  #     iex> PostcodesContext.manage(%{search_term: "EH1"}, :search_postcodes)
  #     {:ok, [%{postal_code: "EH1 1BB", place_name: "Edinburgh"}, %{postal_code: "EH1 2AB", place_name: "Edinburgh"}]}
  def manage(attrs, :search_postcodes) do
    %{search_term: search_term} = attrs
    search_pattern = "#{search_term}%"

    # Use the filter function from the access behavior
    {_count, results} =
      @postcode_access.filter(
        %{
          postal_code_like: search_pattern,
          distinct: :postal_code,
          order_by: :postal_code,
          limit: 10
        },
        :postcode
      )

    if results == [] do
      {:error, :no_postcodes_found}
    else
      {:ok, results}
    end
  end

  @impl Partners.Access.Behaviour.ContextBehaviour
  # Lists all postcodes in the system.
  #
  # This operation retrieves all distinct postcodes, ordered alphabetically.
  # It's typically used to populate dropdown menus or for data export purposes.
  #
  # Parameters:
  #   * `attrs` - An empty map, as this operation doesn't require any parameters
  #
  # Returns:
  #   * `{:ok, postcodes}` - List of all postcode records in the system
  #   * `{:error, :no_postcodes_found}` - If no postcodes exist in the system
  #
  # Examples:
  #
  #     iex> PostcodesContext.manage(%{}, :list_all_postcodes)
  #     {:ok, [%{postal_code: "AB10 1AA", ...}, %{postal_code: "AB10 1AB", ...}, ...]}
  def manage(_attrs, :list_all_postcodes) do
    # Use the filter function from the access behavior
    {_count, results} =
      @postcode_access.filter(
        %{
          distinct: :postal_code,
          order_by: :postal_code
        },
        :postcode
      )

    if results == [] do
      {:error, :no_postcodes_found}
    else
      {:ok, results}
    end
  end

  @impl Partners.Access.Behaviour.ContextBehaviour
  # Fallback function for unimplemented operations.
  #
  # This function handles any operation that is not explicitly implemented
  # in this context module. It logs an error and returns an appropriate error
  # tuple to the caller.
  #
  # Parameters:
  #   * `_attrs` - Any map of attributes, which are ignored
  #   * `operation` - The requested operation atom that is not supported
  #
  # Returns:
  #   * `{:error, :operation_not_supported}` - Always returns this error
  #
  # Examples:
  #
  #     iex> PostcodesContext.manage(%{}, :nonexistent_operation)
  #     {:error, :operation_not_supported}
  #     # And logs: "Unimplemented operation in PostcodeContext: :nonexistent_operation"
  def manage(_attrs, operation) do
    Logger.error("Unimplemented operation in PostcodeContext: #{inspect(operation)}")
    {:error, :operation_not_supported}
  end
end
