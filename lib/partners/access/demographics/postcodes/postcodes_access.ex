defmodule Partners.Access.Demographics.Postcodes.PostcodesAccess do
  @moduledoc """
  Access module for Postcode schema.

  Implements the AccessBehaviour interface for the Postcode schema, providing
  standardized methods for storing, filtering, removing, and loading postcode data.

  This module serves as the data access layer for postcode-related operations,
  encapsulating all database interactions with the Postcode schema. It provides a
  consistent and reusable interface for CRUD operations, allowing the application
  to interact with postcode data without directly coupling to database specifics.

  The module implements four primary operations:
  - `store/2`: Create or update postcode records
  - `filter/2`: Query postcodes with flexible filtering criteria
  - `remove/2`: Delete postcode records
  - `load/2`: Fetch postcode records by specific criteria

  Additionally, it provides convenience functions for common postcode operations
  such as retrieving place names for a postal code or searching postcodes.
  """
  @behaviour Partners.Access.Behaviour.AccessBehaviour

  import Ecto.Query
  alias Partners.Repo
  alias Partners.Access.Demographics.Postcodes.Postcode

  @impl true
  @doc """
  Store a postcode record in the database.

  Creates a new postcode when given `:postcode` as the second parameter,
  or updates an existing postcode when given a Postcode struct.

  ## Parameters

    * `attrs` - Map of attributes to store
    * `schema` - Either the atom `:postcode` or an existing Postcode struct

  ## Returns

    * `{:ok, postcode}` - The stored postcode on success
    * `{:error, changeset}` - Changeset with errors on failure

  ## Examples

      # Create a new postcode
      {:ok, postcode} = PostcodesAccess.store(%{
        country_code: "AU",
        postal_code: "4000",
        place_name: "Brisbane",
        latitude: -27.4698,
        longitude: 153.0251
      }, :postcode)

      # Update an existing postcode
      {:ok, updated_postcode} = PostcodesAccess.store(%{
        place_name: "Brisbane City"
      }, existing_postcode)
  """
  def store(attrs, :postcode) do
    %Postcode{}
    |> Postcode.changeset(attrs)
    |> Repo.insert()
  end

  # Update an existing postcode with new attributes.
  #
  # This is an overloaded version of the `store/2` function that handles
  # updates to existing postcode records.
  #
  # Parameters:
  #   * `attrs` - Map of attributes to update
  #   * `postcode` - Existing Postcode struct to update
  #
  # Returns:
  #   * `{:ok, postcode}` - The updated postcode on success
  #   * `{:error, changeset}` - Changeset with errors on failure
  def store(attrs, %Postcode{} = postcode) do
    postcode
    |> Postcode.changeset(attrs)
    |> Repo.update()
  end

  @impl true
  @doc """
  Filter postcodes based on criteria.

  This function provides a composable query interface where different criteria can be combined
  to create powerful, flexible queries for postcode data. It transforms a map of criteria into
  an Ecto query, executes it, and returns both the matching records and their count.

  ## Parameters

    * `criteria` - Map of filtering criteria, which can include:
      * `{:postal_code, postal_code}` - Filter by exact postal code match
      * `{:postal_code_like, pattern}` - Filter by postal codes starting with pattern
      * `{:place_name, place_name}` - Filter by exact place name match
      * `{:country_code, country_code}` - Filter by country code
      * `{:distinct, :postal_code}` - Return unique postal codes
      * `{:select, fields}` - Select only specific fields
      * `{:limit, limit}` - Limit number of results
      * `{:order_by, field}` - Order by field

    * `schema` - Atom representing the schema type (always `:postcode` for this function)

  ## Returns

    * `{count, postcodes}` - Tuple with count of matching records and the records themselves

  ## Examples

      # Find all postcodes in Australia
      {count, postcodes} = PostcodesAccess.filter(
        %{
          country_code: "AU"
        },
        :postcode
      )

      # Find all unique postal codes starting with "40", limited to 10 results
      {count, postcodes} = PostcodesAccess.filter(
        %{
          postal_code_like: "40",
          distinct: :postal_code,
          limit: 10,
          order_by: :postal_code
        },
        :postcode
      )
  """
  def filter(criteria, :postcode) do
    query = from p in Postcode, as: :postcode

    query =
      Enum.reduce(criteria, query, fn
        {:postal_code, postal_code}, query ->
          from [postcode: p] in query, where: p.postal_code == ^postal_code

        {:postal_code_like, pattern}, query ->
          from [postcode: p] in query, where: like(p.postal_code, ^"#{pattern}%")

        {:place_name, place_name}, query ->
          from [postcode: p] in query, where: p.place_name == ^place_name

        {:country_code, country_code}, query ->
          from [postcode: p] in query, where: p.country_code == ^country_code

        {:distinct, :postal_code}, query ->
          from [postcode: p] in query,
            select: %{id: p.id, postal_code: p.postal_code},
            distinct: [p.postal_code]

        {:select, fields}, query when is_list(fields) ->
          from [postcode: p] in query, select: map(p, ^fields)

        {:limit, limit}, query ->
          from [postcode: p] in query, limit: ^limit

        {:order_by, field}, query ->
          from [postcode: p] in query, order_by: field(p, ^field)

        _, query ->
          query
      end)

    {Repo.aggregate(query, :count), Repo.all(query)}
  end

  @impl true
  @doc """
  Remove a postcode record from the database.

  This function first loads the postcode using the provided criteria,
  then deletes it if a single record is found.

  ## Parameters

    * `criteria` - Map of criteria to identify the postcode to remove
    * `schema` - Atom representing the schema type (always `:postcode` for this function)

  ## Returns

    * `{:ok, postcode}` - The deleted postcode on success
    * `{:error, reason}` - Error information on failure

  ## Examples

      # Delete a postcode by ID
      {:ok, deleted_postcode} = PostcodesAccess.remove(%{id: postcode_id}, :postcode)

      # This will fail if multiple postcodes would match the criteria
      {:error, reason} = PostcodesAccess.remove(%{country_code: "AU"}, :postcode)
  """
  def remove(criteria, :postcode) do
    case load(criteria, :postcode) do
      {:ok, postcode} when is_map(postcode) and not is_list(postcode) ->
        Repo.delete(postcode)

      {:ok, _postcodes} ->
        {:error, "Cannot remove multiple postcodes with this operation"}

      error ->
        error
    end
  end

  @impl true
  @doc """
  Load postcode records by specific criteria.

  This function builds a query based on the provided criteria and returns
  the matching postcode record(s).

  ## Parameters

    * `criteria` - Map of criteria to identify the postcode(s) to load, which can include:
      * `{:id, id}` - Find by postcode ID
      * `{:postal_code, postal_code}` - Find by exact postal code match
      * `{:place_name, place_name}` - Find by exact place name match
      * `{:include, associations}` - Preload specified associations

    * `schema` - Atom representing the schema type (always `:postcode` for this function)

  ## Returns

    * `{:ok, postcode}` - A single matching postcode
    * `{:ok, postcodes}` - List of matching postcodes
    * `{:error, :not_found}` - No matching postcodes found

  ## Examples

      # Load a postcode by ID
      {:ok, postcode} = PostcodesAccess.load(%{id: postcode_id}, :postcode)

      # Load all postcodes for a specific postal code
      {:ok, postcodes} = PostcodesAccess.load(%{postal_code: "4000"}, :postcode)
  """
  def load(criteria, :postcode) do
    query = from p in Postcode, as: :postcode

    query =
      Enum.reduce(criteria, query, fn
        {:id, id}, query ->
          from [postcode: p] in query, where: p.id == ^id

        {:postal_code, postal_code}, query ->
          from [postcode: p] in query, where: p.postal_code == ^postal_code

        {:place_name, place_name}, query ->
          from [postcode: p] in query, where: p.place_name == ^place_name

        {:include, includes}, query ->
          from [postcode: p] in query, preload: ^includes

        _, query ->
          query
      end)

    query
    |> Repo.all()
    |> case do
      [] -> {:error, :not_found}
      [postcode] -> {:ok, postcode}
      [_ | _] = postcodes -> {:ok, postcodes}
    end
  end

  # Convenience functions that use the standard interface internally

  @doc """
  Find all place names for a given postal code.

  This convenience function retrieves all place names associated with a specific postal code.
  Place names are returned in alphabetical order.

  ## Parameters

    * `postal_code` - String representation of the postal code to search for

  ## Returns

    * List of place names as strings

  ## Examples

      # Get all suburbs in the 4000 postal code
      place_names = PostcodesAccess.place_names_for_postal_code("4000")
      # => ["Brisbane", "Brisbane City", "Petrie Terrace", ...]
  """
  def place_names_for_postal_code(postal_code) do
    {_, results} =
      filter(
        %{
          postal_code: postal_code,
          select: [:place_name],
          order_by: :place_name
        },
        :postcode
      )

    Enum.map(results, & &1.place_name)
  end

  @doc """
  Find all place names for a given postcode ID.

  This convenience function retrieves the place name(s) associated with a specific postcode ID.

  ## Parameters

    * `postcode_id` - UUID of the postcode record

  ## Returns

    * List of place names as strings (usually just one for a specific ID)

  ## Examples

      # Get the place name for a specific postcode ID
      place_names = PostcodesAccess.place_names_for_postcode_id(postcode_id)
      # => ["Brisbane City"]
  """
  def place_names_for_postcode_id(postcode_id) do
    case load(%{id: postcode_id}, :postcode) do
      {:ok, postcode} when is_list(postcode) ->
        Enum.map(postcode, & &1.place_name)

      {:ok, postcode} ->
        [postcode.place_name]

      _ ->
        []
    end
  end

  @doc """
  List all postcodes with unique postal_code values.

  This convenience function retrieves a list of all unique postal codes in the system,
  returning both the ID and postal code for each one. The results are sorted by postal code.

  ## Returns

    * List of maps, each containing `id` and `postal_code` keys

  ## Examples

      # Get all unique postal codes
      postcodes = PostcodesAccess.list_postcodes()
      # => [%{id: "uuid1", postal_code: "4000"}, %{id: "uuid2", postal_code: "4001"}, ...]
  """
  def list_postcodes do
    {_, results} = filter(%{distinct: :postal_code, order_by: :postal_code}, :postcode)
    results
  end

  @doc """
  Search postcodes by partial postal_code for autocomplete.

  This convenience function finds all unique postal codes that start with the
  provided search term. Results are limited to 10 matches for performance reasons
  and are sorted by postal code.

  ## Parameters

    * `search_term` - String to match the beginning of postal codes

  ## Returns

    * List of maps, each containing `id` and `postal_code` keys

  ## Examples

      # Search for postal codes starting with "40"
      results = PostcodesAccess.search_by_postal_code("40")
      # => [%{id: "uuid1", postal_code: "4000"}, %{id: "uuid2", postal_code: "4001"}, ...]
  """
  def search_by_postal_code(search_term) do
    {_, results} =
      filter(
        %{
          postal_code_like: search_term,
          distinct: :postal_code,
          order_by: :postal_code,
          limit: 10
        },
        :postcode
      )

    results
  end
end
