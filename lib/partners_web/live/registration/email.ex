defmodule PartnersWeb.Registration.Email do
  @moduledoc """
  Embedded schema for the email step of the registration form.
  Handles validation for email uniqueness.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Partners.Accounts

  @primary_key false
  embedded_schema do
    field :email, :string
  end

  @doc """
  Creates a changeset for the email step.
  Validates email format and uniqueness.
  """
  def changeset(schema \\ %__MODULE__{}, params) do
    schema
    |> cast(params, [:email])
    |> validate_required([:email], message: "Please enter your email address")
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "Please enter a valid email address")
    |> validate_unique()
  end

  # Private function to validate email uniqueness
  defp validate_unique(changeset) do
    email = get_field(changeset, :email)

    if is_nil(email) do
      changeset
    else
      # Since we're dealing with embedded schemas in a multi-step form,
      # and email is in Partners.Accounts.User schema,
      # we need to validate against the users table
      # Using unsafe_validate_unique for real-time validation
      # For embedded schemas in LiveView forms, we need to check against the User schema
      # without actually attempting to insert a record
      email_taken =
        Partners.Repo.exists?(from u in Partners.Accounts.User, where: u.email == ^email)

      if email_taken do
        add_error(changeset, :email, "Email is already registered")
      else
        changeset
      end
    end
  end
end
