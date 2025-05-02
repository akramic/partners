defmodule Partners.Access.Demographics.Postcode do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "postcodes" do
    field :country_code, :string
    field :postal_code, :string
    field :place_name, :string
    field :admin_name1, :string
    field :admin_code1, :string
    field :admin_name2, :string
    field :admin_code2, :string
    field :admin_name3, :string
    field :admin_code3, :string
    field :latitude, :float
    field :longitude, :float
    field :accuracy, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(postcode, attrs) do
    postcode
    |> cast(attrs, [
      :country_code,
      :postal_code,
      :place_name,
      :admin_name1,
      :admin_code1,
      :admin_name2,
      :admin_code2,
      :admin_name3,
      :admin_code3,
      :latitude,
      :longitude,
      :accuracy
    ])
    |> validate_required([:country_code, :postal_code, :place_name])
  end
end
