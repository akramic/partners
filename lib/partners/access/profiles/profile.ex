defmodule Partners.Access.Profiles.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  alias Partners.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "profiles" do
    field :username, :string
    field :dob, :date
    field :gender, Ecto.Enum, values: [:Male, :Female]
    field :marital_status, Ecto.Enum, values: [:Single, :Separated, :Divorced, :Widowed]
    field :terms, :boolean, default: false
    field :video_path, :string
    field :ip_data, :map
    field :telephone, :string
    field :otp, :string, virtual: true
    field :stored_otp, :string, virtual: true
    # For long and lat data
    field :geom, Geo.PostGIS.Geometry

    # Associations
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  def new, do: %__MODULE__{}

  @doc false
  def registration_changeset(profile \\ new(), attrs) do
    profile
    |> cast(attrs, [
      :username,
      :dob,
      :gender,
      :marital_status,
      :terms,
      :ip_data,
      :telephone
    ])
    |> validate_required([
      :username,
      :dob,
      :gender,
      :marital_status,
      :terms,
      :ip_data,
      :telephone
    ])

    # Scope is not required here as this is for a new user
    # |> put_change(:user_id, user_scope.user.id)
  end
end
