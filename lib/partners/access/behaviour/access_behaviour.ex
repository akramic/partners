defmodule Partners.Access.Behaviour.AccessBehaviour do
  @moduledoc """
  Behaviour for data access operations.

  This behaviour defines a consistent interface for performing CRUD operations
  on any schema in the application. By implementing this behaviour, modules can
  provide standardized data access with the following operations:

  - `store/2`: Create or update records
  - `filter/2`: Query records with filtering criteria
  - `remove/2`: Delete records
  - `load/2`: Fetch records by criteria
  """

  @type error :: String.t() | Ecto.Changeset.t()
  @type attrs :: map()
  @type schema :: atom()
  @type criteria :: map() | keyword()

  @doc """
  Store a record in the database.

  Used for both inserting new records and updating existing ones.

  ## Parameters

    * `attrs` - Map of attributes to store
    * `schema` - Atom representing the schema type or an existing schema struct

  ## Returns

    * `{:ok, term()}` - The stored record on success
    * `{:error, error()}` - Error information on failure
  """
  @callback store(attrs(), schema()) :: {:ok, term()} | {:error, error()}

  @doc """
  Filter records based on criteria.

  Provides a composable query interface where different criteria can be combined.

  ## Parameters

    * `criteria` - Map of criteria to filter by
    * `schema` - Atom representing the schema type

  ## Returns

    * `{non_neg_integer(), [schema()]}` - Tuple with count and matching records
  """
  @callback filter(criteria(), schema()) :: {non_neg_integer(), [schema()]}

  @doc """
  Remove a record from the database.

  ## Parameters

    * `criteria` - Map identifying the record to remove
    * `schema` - Atom representing the schema type

  ## Returns

    * `{:ok, term()}` - The removed record on success
    * `{:error, error()}` - Error information on failure
  """
  @callback remove(criteria(), schema()) :: {:ok, term()} | {:error, error()}

  @doc """
  Load one or more records based on criteria.

  ## Parameters

    * `criteria` - Map identifying the record(s) to load
    * `schema` - Atom representing the schema type

  ## Returns

    * `{:ok, term()}` - The loaded record(s) on success
    * `{:error, error()}` - Error information on failure
  """
  @callback load(criteria(), schema()) :: {:ok, term()} | {:error, error()}
end
