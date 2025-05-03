defmodule Partners.Access.Demographics.Occupation.Occupation do
  use Ecto.Schema
  import Ecto.Changeset


  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "occupations" do
    field :category_id, :integer
    field :group_code, :string
    field :category, :string
    field :group, :string

    # Associations
    has_many :profiles, Partners.Access.Profiles.Profile, foreign_key: :occupation_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(occupation, attrs) do
    occupation
    |> cast(attrs, [:category_id, :group_code, :category, :group])
    |> validate_required([:category_id, :group_code, :category, :group])
    |> unique_constraint([:group_code, :group])
  end
end
