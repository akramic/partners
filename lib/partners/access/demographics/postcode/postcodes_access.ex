defmodule Partners.Access.Demographics.Postcode.PostcodesAccess do
  @moduledoc """
  Access module for Postcode schema.

  Implements the AccessBehaviour interface for the Postcode schema, providing
  standardized methods for storing, filtering, removing, and loading postcode data.
  """
  @behaviour Partners.Access.Behaviour.AccessBehaviour

  import Ecto.Query
  alias Partners.Repo
  alias Partners.Access.Demographics.Postcode.Postcode

  @impl true
  def store(attrs, :postcode) do
    %Postcode{}
    |> Postcode.changeset(attrs)
    |> Repo.insert()
  end

  def store(attrs, %Postcode{} = postcode) do
    postcode
    |> Postcode.changeset(attrs)
    |> Repo.update()
  end

  @impl true
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
  """
  def list_postcodes do
    {_, results} = filter(%{distinct: :postal_code, order_by: :postal_code}, :postcode)
    results
  end

  @doc """
  Search postcodes by partial postal_code for autocomplete.
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
