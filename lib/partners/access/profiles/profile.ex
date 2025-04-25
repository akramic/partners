defmodule Partners.Access.Profiles.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  alias Partners.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "profiles" do
    field :username, :string
    field :dob, :date
    field :gender, :string
    field :marital_status, Ecto.Enum, values: [:Single, :Separated, :Divorced, :Widowed]
    field :terms, :boolean, default: false
    field :video_path, :string
    field :ip_data, :map
    field :telephone, :string
    field :otp, :string, virtual: true
    field :stored_otp, :string, virtual: true

    # Associations
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(profile, attrs, user_scope) do
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
    |> put_change(:user_id, user_scope.user.id)
  end
end
