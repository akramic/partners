defmodule Partners.Access.Demographics.Postcode.PostcodesContext do
  @moduledoc """
  Context module for postcode-related operations.

  This module implements the ContextBehaviour interface specifically for
  postcode-related operations. It serves as a domain boundary for interactions
  with postcodes in the system.
  """
  @behaviour Partners.Access.Behaviour.ContextBehaviour

  require Logger
  alias Partners.Access.Demographics.Postcode.PostcodesAccess

  # Use the access module directly
  @postcode_access PostcodesAccess

  @impl Partners.Access.Behaviour.ContextBehaviour
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
  def manage(_attrs, operation) do
    Logger.error("Unimplemented operation in PostcodeContext: #{inspect(operation)}")
    {:error, :operation_not_supported}
  end
end
