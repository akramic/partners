defmodule Partners.Utils.DataTransformers do
  @moduledoc """
  A utility module for transforming data structures in Elixir.
  """

  @doc """
  Converts keys in a map from strings to atoms.
  This is useful for converting parameters from the form submission
  to a format that can be used in Ecto changesets or other Elixir structures.
  Example use using the map returned from the API call fetch_response function:
  string_keys_map |> EmailComponent.key_to_atom
  %{
  inputData: "michael.akram@gmail.com.com",
  isDisposable: false,
  isKnownSpammerDomain: false,
  isMailServerDefined: true,
  isSyntaxValid: true,
  isValid: true
  }

  """

  def key_to_atom(map) do
    Enum.reduce(map, %{}, fn
      # String.to_existing_atom saves us from overloading the VM by
      # creating too many atoms. It'll always succeed because all the fields
      # in the database already exist as atoms at runtime.
      {key, value}, acc when is_atom(key) -> Map.put(acc, key, value)
      {key, value}, acc when is_binary(key) -> Map.put(acc, String.to_atom(key), value)
    end)
  end
end
