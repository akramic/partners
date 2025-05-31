defmodule PartnersWeb.Registration.RegistrationForm do
  @moduledoc """
  Parent embedded schema for the registration multi-step form.
  Combines all steps in a single schema for validation and data management.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__

  @primary_key false
  embedded_schema do
    embeds_one :profile, Profile, on_replace: :update, primary_key: false do
      field :username, :string
      field :dob, :date
    end

    embeds_one :user, User, on_replace: :update, primary_key: false do
      field :email, :string
    end
  end

  def new(registration_form \\ %RegistrationForm{}) do
    registration_form
    |> changeset()
  end

  @doc """
  Creates a changeset for the registration form with all steps.
  """
  def changeset(%RegistrationForm{} = form, attrs \\ %{}) do
    form
    |> cast(attrs, [])
    |> cast_embed(:profile, with: &profile_changeset/2)
    |> cast_embed(:user, with: &user_changeset/2)
  end

  @doc """
  Creates a changeset for the profile step.
  """
  def profile_changeset(profile, params) do
    profile
    |> cast(params, [:username, :dob])
    |> validate_required([:username, :dob])
  end

  @doc """
  Creates a changeset for the user step.
  """
  def user_changeset(user, params) do
    user
    |> cast(params, [:email])
    |> validate_required([:email])
  end

  def validate(%Phoenix.HTML.Form{} = form, attrs) do
    form.source.data
    |> changeset(attrs)
    |> Map.put(:action, :validate)
  end
end
