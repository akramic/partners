defmodule Partners.Access.Demographics.Occupations.OccupationsContext do
  @moduledoc """
  Context module for occupation-related operations.

  This module implements the ContextBehaviour interface specifically for
  occupation-related operations. It serves as a domain boundary for interactions
  with occupations in the system.
  """
  @behaviour Partners.Access.Behaviour.ContextBehaviour

  require Logger
  alias Partners.Access.Demographics.Occupations.OccupationsAccess

  # Use the access module directly
  @occupation_access OccupationsAccess

  @impl Partners.Access.Behaviour.ContextBehaviour
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
  def manage(_attrs, operation) do
    Logger.error("Unimplemented operation in OccupationsContext: #{inspect(operation)}")
    {:error, :operation_not_supported}
  end
end
