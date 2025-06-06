defmodule PartnersWeb.Registration.Username do
  @moduledoc """
  Embedded schema for the username step of the registration form.
  Handles validation for username uniqueness.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Partners.Access.Profiles.Profile

  @primary_key false
  embedded_schema do
    field :username, :string
  end

  @doc """
  Creates a changeset for the username step.
  Validates username format and uniqueness.
  """
  def changeset(schema \\ %__MODULE__{}, params) do
    schema
    |> cast(params, [:username])
    |> validate_required([:username], message: "Please choose a username")
    |> validate_length(:username, min: 3, message: "Username must be at least 3 characters")
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/,
      message: "Username can only contain letters, numbers, and underscores"
    )
    |> validate_unique()
  end

  # Private function to validate username uniqueness
  defp validate_unique(changeset) do
    username = get_field(changeset, :username)

    if is_nil(username) do
      changeset
    else
      # For embedded schemas in LiveView forms, we need to check against the Profile schema
      # since the username field is in the Profile schema, not in User
      username_taken = Partners.Repo.exists?(from p in Profile, where: p.username == ^username)

      if username_taken do
        add_error(changeset, :username, "Username is already taken")
      else
        changeset
      end
    end
  end
end
