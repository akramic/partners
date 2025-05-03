defmodule Partners.Access.Behaviour.ContextBehaviour do
  @moduledoc """
  Behaviour for context modules that define domain operations.

  This behaviour defines a consistent interface for performing business operations
  that may involve multiple data access calls or external services. Context modules
  implement this behaviour to provide a unified entry point for domain operations.

  The `manage/2` function serves as the main entry point, with different operations
  distinguished by the atom passed as the second parameter.

  In a liveview - example usage:

  ```elixir

  defmodule PartnersWeb.PostcodeSearchLive do
  use PartnersWeb, :live_view
  alias Partners.DemographicsContext

  # ...

  def mount(_params, _session, socket) do
    {:ok, postcodes} = DemographicsContext.manage(%{}, :list_all_postcodes)
    {:ok, assign(socket, postcodes: postcodes, search_results: [])}
  end

  def handle_event("search", %{"search" => %{"term" => term}}, socket) do
    {:ok, results} = DemographicsContext.manage(%{search_term: term}, :search_postcodes)
    {:noreply, assign(socket, search_results: results)}
  end

  def handle_event("find_places", %{"postal_code" => postal_code}, socket) do
    case DemographicsContext.manage(%{postal_code: postal_code}, :find_place_names) do
      {:ok, place_names} ->
        {:noreply, assign(socket, place_names: place_names)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "No places found for that postcode")}
    end
  end

  # ...
  end
  ```


  """

  @type error :: String.t() | Ecto.Changeset.t() | atom()
  @type attrs :: map()
  @type operation :: atom()

  @doc """
  Perform a domain operation.

  This is the primary entry point for business logic. Each operation is represented
  by an atom, and the attributes contain the data needed for the operation.

  ## Parameters

    * `attrs` - Map of attributes required for the operation
    * `operation` - Atom representing the operation to perform

  ## Returns

    * `{:ok, term()}` - Operation result on success
    * `{:error, error()}` - Error information on failure
  """
  @callback manage(attrs(), operation()) :: {:ok, term()} | {:error, error()}
end
