defmodule Partners.Access.Demographics.Occupations.OccupationsContext do
  @moduledoc """
  Context module for occupation-related operations.

  This module implements the ContextBehaviour interface specifically for
  occupation-related operations. It serves as a domain boundary for interactions
  with occupations in the system.

  ## Architecture Overview

  The OccupationsContext is part of the application's layered architecture:

  1. **Web Layer** (LiveViews/Controllers) - Handles HTTP requests and UI interactions
  2. **Context Layer** (OccupationsContext) - Contains business logic and orchestration
  3. **Access Layer** (OccupationsAccess) - Manages data persistence operations
  4. **Schema Layer** (Occupation) - Defines the structure and validation rules

  This separation allows for:

  * **Encapsulation** - Domain logic is contained within appropriate boundaries
  * **Testability** - Each layer can be tested in isolation
  * **Flexibility** - Implementation details can change without affecting clients
  * **Composability** - Contexts can be combined for complex operations

  ## Usage Examples

  The OccupationsContext provides a consistent interface for all occupation operations,
  simplifying client code and enforcing business rules. Here are examples showing
  how to use this module in different contexts:

  ### Fetching Occupation Groups for a Category

  ```elixir
  # In a LiveView or controller handling occupation selection
  def mount(_params, _session, socket) do
    # First, get all occupation categories
    case OccupationsContext.manage(%{}, :list_all_occupations) do
      {:ok, occupations} ->
        categories = Enum.uniq_by(occupations, & &1.category)
        {:ok, assign(socket, categories: categories, selected_category: nil, groups: [])}

      {:error, :no_occupations_found} ->
        {:ok, assign(socket, categories: [], selected_category: nil, groups: [])}
    end
  end

  # Then handle category selection to get groups
  def handle_event("select_category", %{"category" => category}, socket) do
    case OccupationsContext.manage(%{category: category}, :groups_for_category) do
      {:ok, groups} ->
        {:noreply, assign(socket, groups: groups, selected_category: category)}

      {:error, :no_groups_found} ->
        {:noreply, assign(socket, groups: [], selected_category: category)}
    end
  end
  ```

  ### Using Occupation Search in a Form

  ```elixir
  # In a LiveView or controller handling occupation search
  def handle_event("search_occupations", %{"search" => %{"term" => term}}, socket) do
    case OccupationsContext.manage(%{search_term: term}, :search_occupations) do
      {:ok, results} ->
        {:noreply, assign(socket, search_results: results)}

      {:error, :no_occupations_found} ->
        {:noreply, assign(socket, search_results: [])}
    end
  end
  ```

  ### Retrieving a Specific Occupation

  ```elixir
  # In a LiveView or controller handling profile creation/update
  def handle_event("select_occupation", %{"occupation_id" => occupation_id}, socket) do
    case OccupationsContext.manage(%{occupation_id: occupation_id}, :occupation_for_id) do
      {:ok, occupation} ->
        updated_profile = Map.put(socket.assigns.profile, :occupation, occupation)
        {:noreply, assign(socket, :profile, updated_profile)}

      {:error, :occupation_not_found} ->
        {:noreply, put_flash(socket, :error, "Selected occupation not found")}
    end
  end
  ```

  ### Loading All Occupations

  ```elixir
  # In a LiveView or controller initializing a form with occupations
  def mount(_params, _session, socket) do
    case OccupationsContext.manage(%{}, :list_all_occupations) do
      {:ok, occupations} ->
        {:ok, assign(socket, :occupations, occupations)}

      {:error, :no_occupations_found} ->
        {:ok, assign(socket, :occupations, [])}
    end
  end
  ```

  ### Integration with Profile Context

  The real power of the context pattern becomes apparent when composing multiple contexts:

  ```elixir
  # In a profile creation wizard LiveView
  def handle_event("save_occupation", %{"profile" => %{"occupation_id" => occupation_id}}, socket) do
    # First, retrieve the occupation details
    case OccupationsContext.manage(%{occupation_id: occupation_id}, :occupation_for_id) do
      {:ok, occupation} ->
        # Then, update the profile with the selected occupation
        case ProfilesContext.manage(
          %{profile: socket.assigns.profile, attrs: %{occupation_id: occupation.id}},
          :update_profile_occupation
        ) do
          {:ok, updated_profile} ->
            {:noreply,
             socket
             |> assign(:profile, updated_profile)
             |> put_flash(:info, "Occupation updated successfully")
             |> push_navigate(to: ~p"/profiles/1/edit/interests")}

          {:error, changeset} ->
            {:noreply, assign(socket, :changeset, changeset)}
        end

      {:error, :occupation_not_found} ->
        {:noreply, put_flash(socket, :error, "Invalid occupation selected")}
    end
  end
  ```

  ### Advanced Pattern: Cross-Context Operations

  Context modules can be composed for more complex operations:

  ```elixir
  # In a demographics dashboard service module
  def occupation_statistics_by_location do
    # Get all postcodes
    {:ok, postcodes} = PostcodesContext.manage(%{}, :list_all_postcodes)

    # For each postcode, find profiles in that area
    postcode_stats = Enum.map(postcodes, fn postcode ->
      {:ok, {profile_count, _profiles}} = ProfilesContext.manage(
        %{postcode_id: postcode.id},
        :filter_profiles_by_postcode
      )

      # Get occupation breakdown for those profiles
      occupation_counts =
        if profile_count > 0 do
          {:ok, occupation_summary} = ProfilesContext.manage(
            %{postcode_id: postcode.id},
            :occupation_summary_by_postcode
          )
          occupation_summary
        else
          []
        end

      # Return statistics for this postcode
      %{
        postcode: postcode.postal_code,
        place_name: postcode.place_name,
        total_profiles: profile_count,
        occupations: occupation_counts
      }
    end)

    {:ok, postcode_stats}
  end
  ```

  These examples illustrate how the OccupationsContext module provides a flexible interface
  for working with occupation data in various scenarios, from simple queries to
  more complex filtering operations, while enabling composition with other contexts
  for sophisticated domain operations.
  """
  @behaviour Partners.Access.Behaviour.ContextBehaviour

  require Logger
  alias Partners.Access.Demographics.Occupations.OccupationsAccess

  # Use the access module directly
  @occupation_access OccupationsAccess

  @impl Partners.Access.Behaviour.ContextBehaviour
  @doc """
  Perform a domain operation related to occupations.

  This is the primary entry point for all occupation-related business logic. Each operation
  is represented by an atom as the second parameter, and the attributes contain the data
  needed for that specific operation.

  ## Common Operations

  * `:groups_for_category` - Get occupation groups for a category name
  * `:groups_for_category_id` - Get occupation groups for a category ID
  * `:occupation_for_id` - Get a specific occupation by ID
  * `:search_occupations` - Search for occupations matching a term
  * `:list_all_occupations` - List all distinct occupations in the system

  ## Parameters

    * `attrs` - Map of attributes required for the specific operation
    * `operation` - Atom representing the operation to perform

  ## Returns

    * `{:ok, term()}` - Operation result on success
    * `{:error, error()}` - Error information on failure
  """
  # Fetches all unique occupation groups for a specified category.
  #
  # Parameters:
  #   * `attrs` - Map containing the following keys:
  #     * `:category` - The occupation category name (e.g., "Professionals")
  #
  # Returns:
  #   * `{:ok, groups}` - List of group names on success
  #   * `{:error, :no_groups_found}` - If no groups are found for the category
  #
  # Examples:
  #
  #     iex> OccupationsContext.manage(%{category: "Professionals"}, :groups_for_category)
  #     {:ok, ["Education Professionals", "Health Professionals", "ICT Professionals"]}
  def manage(attrs, :groups_for_category) do
    %{category: category} = attrs

    # Use the filter function from the access behavior
    {_count, results} =
      @occupation_access.filter(
        %{
          category: category,
          select: [:group],
          order_by: :group
        },
        :occupation
      )

    groups = Enum.map(results, & &1.group)

    if groups == [] do
      {:error, :no_groups_found}
    else
      {:ok, groups}
    end
  end

  @impl Partners.Access.Behaviour.ContextBehaviour
  # Fetches all unique occupation groups for a specified category ID.
  #
  # This operation retrieves occupation groups filtered by their category ID,
  # useful for hierarchical occupation selection interfaces.
  #
  # Parameters:
  #   * `attrs` - Map containing the following keys:
  #     * `:category_id` - The ID of the occupation category
  #
  # Returns:
  #   * `{:ok, groups}` - List of group names on success
  #   * `{:error, :no_groups_found}` - If no groups are found for the category ID
  #
  # Examples:
  #
  #     iex> OccupationsContext.manage(%{category_id: 5}, :groups_for_category_id)
  #     {:ok, ["Education Professionals", "Health Professionals", "ICT Professionals"]}
  def manage(attrs, :groups_for_category_id) do
    %{category_id: category_id} = attrs

    # Use the filter function from the access behavior
    {_count, results} =
      @occupation_access.filter(
        %{
          category_id: category_id,
          select: [:group],
          order_by: :group
        },
        :occupation
      )

    groups = Enum.map(results, & &1.group)

    if groups == [] do
      {:error, :no_groups_found}
    else
      {:ok, groups}
    end
  end

  @impl Partners.Access.Behaviour.ContextBehaviour
  # Retrieves a specific occupation by its ID.
  #
  # This operation loads a single occupation record by its database ID.
  # It's typically used when a user selects an occupation from a list and
  # the system needs the full occupation details.
  #
  # Parameters:
  #   * `attrs` - Map containing the following keys:
  #     * `:occupation_id` - The database ID of the occupation to retrieve
  #
  # Returns:
  #   * `{:ok, occupation}` - The occupation record on success
  #   * `{:error, :occupation_not_found}` - If no occupation with the given ID exists
  #
  # Examples:
  #
  #     iex> OccupationsContext.manage(%{occupation_id: 42}, :occupation_for_id)
  #     {:ok, %{id: 42, category: "Professionals", group: "Health Professionals",
  #             name: "Medical Doctor", code: "2211", group_code: "221"}}
  def manage(attrs, :occupation_for_id) do
    %{occupation_id: occupation_id} = attrs

    # Use the load function from the access behavior
    case @occupation_access.load(%{id: occupation_id}, :occupation) do
      {:ok, occupation} when is_list(occupation) ->
        {:ok, List.first(occupation)}

      {:ok, occupation} ->
        {:ok, occupation}

      _ ->
        {:error, :occupation_not_found}
    end
  end

  @impl Partners.Access.Behaviour.ContextBehaviour
  # Searches for occupations that match a search pattern.
  #
  # This operation performs a search for occupations based on their group code,
  # which typically includes both the numeric code and a text description.
  # It's most commonly used in autocomplete interfaces for occupation selection.
  #
  # Parameters:
  #   * `attrs` - Map containing the following keys:
  #     * `:search_term` - The search string to match against occupation group codes
  #
  # Returns:
  #   * `{:ok, occupations}` - List of occupation records matching the search term
  #   * `{:error, :no_occupations_found}` - If no occupations match the search term
  #
  # Examples:
  #
  #     iex> OccupationsContext.manage(%{search_term: "doctor"}, :search_occupations)
  #     {:ok, [%{name: "Medical Doctor", group: "Health Professionals"},
  #            %{name: "Veterinary Doctor", group: "Health Professionals"}]}
  def manage(attrs, :search_occupations) do
    %{search_term: search_term} = attrs

    # Use the filter function from the access behavior
    {_count, results} =
      @occupation_access.filter(
        %{
          group_code_like: search_term,
          distinct: :group_code,
          order_by: :group_code,
          limit: 10
        },
        :occupation
      )

    if results == [] do
      {:error, :no_occupations_found}
    else
      {:ok, results}
    end
  end

  @impl Partners.Access.Behaviour.ContextBehaviour
  # Lists all occupations in the system.
  #
  # This operation retrieves all distinct occupations, ordered by their group code.
  # It's typically used to populate dropdown menus or for data export purposes.
  #
  # Parameters:
  #   * `attrs` - An empty map, as this operation doesn't require any parameters
  #
  # Returns:
  #   * `{:ok, occupations}` - List of all occupation records in the system
  #   * `{:error, :no_occupations_found}` - If no occupations exist in the system
  #
  # Examples:
  #
  #     iex> OccupationsContext.manage(%{}, :list_all_occupations)
  #     {:ok, [%{name: "Accountant", group: "Business Professionals"},
  #            %{name: "Actor", group: "Creative Professionals"}, ...]}
  def manage(_attrs, :list_all_occupations) do
    # Use the filter function from the access behavior
    {_count, results} =
      @occupation_access.filter(
        %{
          distinct: :group_code,
          order_by: :group_code
        },
        :occupation
      )

    if results == [] do
      {:error, :no_occupations_found}
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
  #     iex> OccupationsContext.manage(%{}, :nonexistent_operation)
  #     {:error, :operation_not_supported}
  #     # And logs: "Unimplemented operation in OccupationsContext: :nonexistent_operation"
  def manage(_attrs, operation) do
    Logger.error("Unimplemented operation in OccupationsContext: #{inspect(operation)}")
    {:error, :operation_not_supported}
  end
end
