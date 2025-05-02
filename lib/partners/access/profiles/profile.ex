defmodule Partners.Access.Profiles.Profile do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Partners.Accounts.User
  alias Partners.Access.Demographics.Postcode

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
    field :place_name, :string
    # For long and lat data
    field :geom, Geo.PostGIS.Geometry

    # Associations
    belongs_to :user, User
    belongs_to :postcode, Postcode

    timestamps(type: :utc_datetime)
  end

  def new, do: %__MODULE__{}

  @doc """
  Changeset for initial user registration.
  Postcode and place_name are not required at registration and will be added later.
  """
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

  # Custom function to validate place_name belongs to the selected postcode
  # Only validates if both postcode_id and place_name are present
  defp maybe_validate_place_name_for_postcode(changeset) do
    case {get_field(changeset, :postcode_id), get_field(changeset, :place_name)} do
      # Skip if no postcode_id
      {nil, _} ->
        changeset

      # Skip if no place_name
      {_, nil} ->
        changeset

      {postcode_id, place_name} ->
        # Query to check if the place_name exists for the given postcode
        query =
          from p in Postcode,
            where: p.id == ^postcode_id and p.place_name == ^place_name,
            select: count(p.id)

        case Partners.Repo.one(query) do
          0 -> add_error(changeset, :place_name, "is not valid for the selected postal code")
          _ -> changeset
        end
    end
  end

  # Update the geom field based on the postcode's latitude and longitude
  def update_geom_from_postcode(profile) do
    if profile.postcode_id && profile.place_name do
      # Find the postcode
      postcode =
        Partners.Repo.get_by(Postcode,
          id: profile.postcode_id,
          place_name: profile.place_name
        )

      if postcode && postcode.latitude && postcode.longitude do
        # Create a point from the postcode's coordinates
        point = %Geo.Point{
          coordinates: {postcode.longitude, postcode.latitude},
          srid: 4326
        }

        # Update the profile with the new geom
        profile
        |> Ecto.Changeset.change(%{geom: point})
        |> Partners.Repo.update()
      else
        {:error, :invalid_coordinates}
      end
    else
      {:error, :missing_postcode_info}
    end
  end

  # Function to query for profiles near a given point
  # distance in meters
  def near_point(longitude, latitude, distance \\ 5000) do
    # Create a point geometry from the given coordinates
    point = %Geo.Point{coordinates: {longitude, latitude}, srid: 4326}

    # Query for profiles within the given distance
    query =
      from p in __MODULE__,
        where: fragment("ST_DWithin(?::geography, ?::geography, ?)", p.geom, ^point, ^distance),
        order_by: fragment("ST_Distance(?::geography, ?::geography)", p.geom, ^point)

    Partners.Repo.all(query)
  end

  @doc """
  Changeset for updating a profile's location information.
  This is separate from the registration changeset since postcode and place_name
  are added after initial registration.
  """
  def location_changeset(profile, attrs) do
    profile
    |> cast(attrs, [:postcode_id, :place_name])
    |> validate_required([:postcode_id, :place_name])
    |> foreign_key_constraint(:postcode_id)
    |> maybe_validate_place_name_for_postcode()
  end

  @doc """
  Updates a profile with location information and automatically sets the geom field.
  This is a convenience function that combines the location_changeset and
  update_geom_from_postcode functions.
  """
  def update_location(profile, attrs) do
    Partners.Repo.transaction(fn ->
      # First update the profile with the location information
      with {:ok, updated_profile} <-
             profile
             |> location_changeset(attrs)
             |> Partners.Repo.update(),
           # Then update the geom field based on the new location
           {:ok, profile_with_geom} <- update_geom_from_postcode(updated_profile) do
        profile_with_geom
      else
        {:error, changeset} -> Partners.Repo.rollback(changeset)
        error -> Partners.Repo.rollback(error)
      end
    end)
  end
end
