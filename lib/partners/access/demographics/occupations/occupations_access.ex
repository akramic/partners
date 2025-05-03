defmodule Partners.Access.Demographics.Occupations.OccupationsAccess do
  @moduledoc """
  Access module for Occupation schema.

  Implements the AccessBehaviour interface for the Occupation schema, providing
  standardized methods for storing, filtering, removing, and loading occupation data.

  This module serves as the data access layer for occupation-related operations,
  encapsulating all database interactions with the Occupation schema. It provides a
  consistent and reusable interface for CRUD operations, allowing the application
  to interact with occupation data without directly coupling to database specifics.

  The module implements four primary operations:
  - `store/2`: Create or update occupation records
  - `filter/2`: Query occupations with flexible filtering criteria
  - `remove/2`: Delete occupation records
  - `load/2`: Fetch occupation records by specific criteria

  Additionally, it provides convenience functions for common occupation operations
  such as retrieving groups for a category or searching occupations.
  """
  @behaviour Partners.Access.Behaviour.AccessBehaviour

  import Ecto.Query
  alias Partners.Repo
  alias Partners.Access.Demographics.Occupations.Occupation

  @impl true
  @doc """
  Store an occupation record in the database.

  Creates a new occupation when given `:occupation` as the second parameter,
  or updates an existing occupation when given an Occupation struct.

  ## Parameters

    * `attrs` - Map of attributes to store
    * `schema` - Either the atom `:occupation` or an existing Occupation struct

  ## Returns

    * `{:ok, occupation}` - The stored occupation on success
    * `{:error, changeset}` - Changeset with errors on failure

  ## Examples

      # Create a new occupation
      {:ok, occupation} = OccupationsAccess.store(%{
        category_id: 1,
        group_code: "241",
        category: "Professionals",
        group: "Health Professionals"
      }, :occupation)

      # Update an existing occupation
      {:ok, updated_occupation} = OccupationsAccess.store(%{
        group: "Medical Professionals"
      }, existing_occupation)
  """
  def store(attrs, :occupation) do
    %Occupation{}
    |> Occupation.changeset(attrs)
    |> Repo.insert()
  end

  # Update an existing occupation with new attributes.
  #
  # This is an overloaded version of the `store/2` function that handles
  # updates to existing occupation records.
  #
  # Parameters:
  #   * `attrs` - Map of attributes to update
  #   * `occupation` - Existing Occupation struct to update
  #
  # Returns:
  #   * `{:ok, occupation}` - The updated occupation on success
  #   * `{:error, changeset}` - Changeset with errors on failure
  def store(attrs, %Occupation{} = occupation) do
    occupation
    |> Occupation.changeset(attrs)
    |> Repo.update()
  end

  @impl true
  # Filter occupations based on criteria.
  #
  # This function provides a composable query interface where different criteria can be combined
  # to create powerful, flexible queries for occupation data. It transforms a map of criteria into
  # an Ecto query, executes it, and returns both the matching records and their count.
  #
  # Parameters:
  #   * `criteria` - Map of filtering criteria, which can include:
  #     * `{:category_id, category_id}` - Filter by category ID
  #     * `{:group_code, group_code}` - Filter by exact group code match
  #     * `{:group_code_like, pattern}` - Filter by group codes starting with pattern
  #     * `{:category, category}` - Filter by exact category match
  #     * `{:group, group}` - Filter by exact group match
  #     * `{:distinct, :group_code}` - Return unique group codes
  #     * `{:select, fields}` - Select only specific fields
  #     * `{:limit, limit}` - Limit number of results
  #     * `{:order_by, field}` - Order by field
  #
  # Returns:
  #   * `{count, occupations}` - Tuple with count of matching records and the records themselves
  #
  # Examples:
  #
  #     # Find all occupations in the "Professionals" category
  #     {count, occupations} = OccupationsAccess.filter(
  #       %{
  #         category: "Professionals"
  #       },
  #       :occupation
  #     )
  #
  #     # Find all unique occupation group codes starting with "24", limited to 10 results
  #     {count, occupations} = OccupationsAccess.filter(
  #       %{
  #         group_code_like: "24",
  #         distinct: :group_code,
  #         limit: 10,
  #         order_by: :group_code
  #       },
  #       :occupation
  #     )
  def filter(criteria, :occupation) do
    query = from o in Occupation, as: :occupation

    query =
      Enum.reduce(criteria, query, fn
        {:category_id, category_id}, query ->
          from [occupation: o] in query, where: o.category_id == ^category_id

        {:group_code, group_code}, query ->
          from [occupation: o] in query, where: o.group_code == ^group_code

        {:group_code_like, pattern}, query ->
          from [occupation: o] in query, where: like(o.group_code, ^"#{pattern}%")

        {:category, category}, query ->
          from [occupation: o] in query, where: o.category == ^category

        {:group, group}, query ->
          from [occupation: o] in query, where: o.group == ^group

        {:distinct, :group_code}, query ->
          from [occupation: o] in query,
            select: %{id: o.id, group_code: o.group_code, group: o.group},
            distinct: [o.group_code]

        {:select, fields}, query when is_list(fields) ->
          from [occupation: o] in query, select: map(o, ^fields)

        {:limit, limit}, query ->
          from [occupation: o] in query, limit: ^limit

        {:order_by, field}, query ->
          from [occupation: o] in query, order_by: field(o, ^field)

        _, query ->
          query
      end)

    {Repo.aggregate(query, :count), Repo.all(query)}
  end

  @impl true
  # Remove an occupation record from the database.
  #
  # This function first loads the occupation using the provided criteria,
  # then deletes it if a single record is found.
  #
  # Parameters:
  #   * `criteria` - Map of criteria to identify the occupation to remove
  #   * `schema` - Atom representing the schema type (always `:occupation` for this function)
  #
  # Returns:
  #   * `{:ok, occupation}` - The deleted occupation on success
  #   * `{:error, reason}` - Error information on failure
  #
  # Examples:
  #
  #     # Delete an occupation by ID
  #     {:ok, deleted_occupation} = OccupationsAccess.remove(%{id: occupation_id}, :occupation)
  #
  #     # This will fail if multiple occupations would match the criteria
  #     {:error, reason} = OccupationsAccess.remove(%{category: "Professionals"}, :occupation)
  def remove(criteria, :occupation) do
    case load(criteria, :occupation) do
      {:ok, occupation} when is_map(occupation) and not is_list(occupation) ->
        Repo.delete(occupation)

      {:ok, _occupations} ->
        {:error, "Cannot remove multiple occupations with this operation"}

      error ->
        error
    end
  end

  @impl true
  @doc """
  Load occupation records by specific criteria.

  This function builds a query based on the provided criteria and returns
  the matching occupation record(s).

  ## Parameters

    * `criteria` - Map of criteria to identify the occupation(s) to load, which can include:
      * `{:id, id}` - Find by occupation ID
      * `{:category_id, category_id}` - Find by category ID
      * `{:group_code, group_code}` - Find by exact group code match
      * `{:category, category}` - Find by exact category match
      * `{:group, group}` - Find by exact group match
      * `{:include, associations}` - Preload specified associations

    * `schema` - Atom representing the schema type (always `:occupation` for this function)

  ## Returns

    * `{:ok, occupation}` - A single matching occupation
    * `{:ok, occupations}` - List of matching occupations
    * `{:error, :not_found}` - No matching occupations found

  ## Examples

      # Load an occupation by ID
      {:ok, occupation} = OccupationsAccess.load(%{id: occupation_id}, :occupation)

      # Load all occupations for a specific category
      {:ok, occupations} = OccupationsAccess.load(%{category: "Professionals"}, :occupation)
  """
  def load(criteria, :occupation) do
    query = from o in Occupation, as: :occupation

    query =
      Enum.reduce(criteria, query, fn
        {:id, id}, query ->
          from [occupation: o] in query, where: o.id == ^id

        {:category_id, category_id}, query ->
          from [occupation: o] in query, where: o.category_id == ^category_id

        {:group_code, group_code}, query ->
          from [occupation: o] in query, where: o.group_code == ^group_code

        {:category, category}, query ->
          from [occupation: o] in query, where: o.category == ^category

        {:group, group}, query ->
          from [occupation: o] in query, where: o.group == ^group

        {:include, includes}, query ->
          from [occupation: o] in query, preload: ^includes

        _, query ->
          query
      end)

    query
    |> Repo.all()
    |> case do
      [] -> {:error, :not_found}
      [occupation] -> {:ok, occupation}
      [_ | _] = occupations -> {:ok, occupations}
    end
  end

  # Convenience functions that use the standard interface internally

  # Find all groups for a given category.
  #
  # This convenience function retrieves all occupation groups that belong to a specific category.
  # Groups are returned in alphabetical order.
  #
  # Parameters:
  #   * `category` - String representation of the category to search for
  #
  # Returns:
  #   * List of group names as strings
  #
  # Examples:
  #
  #     # Get all occupation groups in the "Professionals" category
  #     groups = OccupationsAccess.groups_for_category("Professionals")
  #     # => ["Engineering Professionals", "Health Professionals", "Legal Professionals", ...]
  def groups_for_category(category) do
    {_, results} =
      filter(
        %{
          category: category,
          select: [:group],
          order_by: :group
        },
        :occupation
      )

    Enum.map(results, & &1.group)
  end

  # Find all groups for a given category ID.
  #
  # This convenience function retrieves all occupation groups that belong to a specific category ID.
  # Groups are returned in alphabetical order.
  #
  # Parameters:
  #   * `category_id` - Integer ID of the category to search for
  #
  # Returns:
  #   * List of group names as strings
  #
  # Examples:
  #
  #     # Get all occupation groups for category ID 2
  #     groups = OccupationsAccess.groups_for_category_id(2)
  #     # => ["Clerical Workers", "Personal Service Workers", "Sales Workers", ...]
  def groups_for_category_id(category_id) do
    {_, results} =
      filter(
        %{
          category_id: category_id,
          select: [:group],
          order_by: :group
        },
        :occupation
      )

    Enum.map(results, & &1.group)
  end

  # List all occupations with unique group_code values.
  #
  # This convenience function retrieves a list of all unique occupation group codes in the system,
  # returning the ID, group code, and group for each one. The results are sorted by group code.
  #
  # Returns:
  #   * List of maps, each containing `id`, `group_code`, and `group` keys
  #
  # Examples:
  #
  #     # Get all unique occupation group codes
  #     occupations = OccupationsAccess.list_occupations()
  #     # => [%{id: "uuid1", group_code: "100", group: "Managers"},
  #     #     %{id: "uuid2", group_code: "200", group: "Professionals"}, ...]
  def list_occupations do
    {_, results} = filter(%{distinct: :group_code, order_by: :group_code}, :occupation)
    results
  end

  # Search occupations by partial group_code for autocomplete.
  #
  # This convenience function finds all unique occupation group codes that start with the
  # provided search term. Results are limited to 10 matches for performance reasons
  # and are sorted by group code.
  #
  # Parameters:
  #   * `search_term` - String to match the beginning of group codes
  #
  # Returns:
  #   * List of maps, each containing `id`, `group_code`, and `group` keys
  #
  # Examples:
  #
  #     # Search for occupation group codes starting with "24"
  #     results = OccupationsAccess.search_by_group_code("24")
  #     # => [%{id: "uuid1", group_code: "241", group: "Health Professionals"},
  #     #     %{id: "uuid2", group_code: "242", group: "Tertiary Education Teachers"}, ...]
  def search_by_group_code(search_term) do
    {_, results} =
      filter(
        %{
          group_code_like: search_term,
          distinct: :group_code,
          order_by: :group_code,
          limit: 10
        },
        :occupation
      )

    results
  end
end
