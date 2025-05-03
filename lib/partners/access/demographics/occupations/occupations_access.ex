defmodule Partners.Access.Demographics.Occupations.OccupationsAccess do
  @moduledoc """
  Access module for Occupation schema.

  Implements the AccessBehaviour interface for the Occupation schema, providing
  standardized methods for storing, filtering, removing, and loading occupation data.
  """
  @behaviour Partners.Access.Behaviour.AccessBehaviour

  import Ecto.Query
  alias Partners.Repo
  alias Partners.Access.Demographics.Occupations.Occupation

  @impl true
  def store(attrs, :occupation) do
    %Occupation{}
    |> Occupation.changeset(attrs)
    |> Repo.insert()
  end

  def store(attrs, %Occupation{} = occupation) do
    occupation
    |> Occupation.changeset(attrs)
    |> Repo.update()
  end

  @impl true
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

  @doc """
  Find all groups for a given category.
  """
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

  @doc """
  Find all groups for a given category ID.
  """
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

  @doc """
  List all occupations with unique group_code values.
  """
  def list_occupations do
    {_, results} = filter(%{distinct: :group_code, order_by: :group_code}, :occupation)
    results
  end

  @doc """
  Search occupations by partial group_code for autocomplete.
  """
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
