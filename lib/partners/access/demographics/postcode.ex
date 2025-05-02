defmodule Partners.Access.Demographics.Postcode do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

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

    # Associations
    has_many :profiles, Partners.Access.Profiles.Profile, foreign_key: :postcode_id

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

  # Function to find all place names for a given postal code
  def place_names_for_postal_code(postal_code) do
    query =
      from p in __MODULE__,
        where: p.postal_code == ^postal_code,
        select: p.place_name,
        order_by: p.place_name,
        distinct: true

    Partners.Repo.all(query)
  end

  # Function to find all place names for a given postcode ID
  def place_names_for_postcode_id(postcode_id) do
    query =
      from p in __MODULE__,
        where: p.id == ^postcode_id,
        select: p.place_name,
        order_by: p.place_name

    Partners.Repo.all(query)
  end

  # Function to find all postcodes (with unique postal_code values)
  def list_postcodes do
    query =
      from p in __MODULE__,
        select: %{id: p.id, postal_code: p.postal_code},
        order_by: p.postal_code,
        distinct: [p.postal_code]

    Partners.Repo.all(query)
  end

  # Function to find postcodes by partial postal_code for autocomplete
  def search_by_postal_code(search_term) do
    search_pattern = "#{search_term}%"

    query =
      from p in __MODULE__,
        where: like(p.postal_code, ^search_pattern),
        select: %{id: p.id, postal_code: p.postal_code},
        order_by: p.postal_code,
        distinct: [p.postal_code],
        limit: 10

    Partners.Repo.all(query)
  end
end
