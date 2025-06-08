defmodule Partners.Access.Profiles.Profile do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Partners.Accounts.User
  alias Partners.Access.Demographics.Postcodes.Postcode
  alias Partners.Access.Demographics.Occupations.Occupation

  use Timex

  @max_age 100
  @min_age 18

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "profiles" do
    field :username, :string
    field :dob, :date
    field :gender, Ecto.Enum, values: [:Male, :Female]
    field :marital_status, Ecto.Enum, values: [:Single, :Separated, :Divorced, :Widowed]
    field :terms, :boolean, default: false
    field :video_path, :string
    field :image_path, :string
    # Required in changeset
    field :ip_data, :map
    field :telephone, :string
    field :otp, :string, virtual: true
    field :stored_otp, :string, virtual: true

    # For long and lat data
    field :geom, Geo.PostGIS.Geometry

    # Associations
    belongs_to :user, User
    belongs_to :postcode, Postcode
    belongs_to :occupation, Occupation

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
    |> validate_username()

    # Scope is not required here as this is for a new user
    # |> put_change(:user_id, user_scope.user.id)
  end

  defp validate_username(struct_or_changeset) do
    struct_or_changeset
    |> validate_length(:username, min: 6, max: 72)
    |> validate_format(:username, ~r/^[a-zA-Z-_0-9]+$/,
      message: "only letters, numbers, - and _ allowed"
    )
    |> unsafe_validate_unique(
      :username,
      Partners.Repo,
      message: "this username is already taken"
    )
    |> unique_constraint(:username, message: "this username is already taken")
  end

  defp validate_dob_min_age(changeset) do
    validate_change(changeset, :dob, fn :dob, dob ->
      if Timex.after?(dob, latest_dob_allowed()) do
        [dob: "must be at least #{@min_age} to join"]
      else
        []
      end
    end)
  end

  defp validate_dob_max_age(changeset) do
    validate_change(changeset, :dob, fn :dob, dob ->
      if Timex.before?(dob, earliest_dob_allowed()) do
        [dob: "cannot join if older than #{@max_age}"]
      else
        []
      end
    end)
  end

  defp validate_accepted(changeset) do
    validate_change(changeset, :terms, fn :terms, terms ->
      if terms do
        []
      else
        [terms: "need to accept terms of membership"]
      end
    end)
  end

  # defp validate_telephone(struct_or_changeset, country_code) do
  #   validate_change(struct_or_changeset, :telephone, fn :telephone, telephone ->
  #     with true <- ExPhoneNumber.is_possible_number?(telephone),
  #          true <- ExPhoneNumber.is_valid_number?(telephone) do
  #       case ExPhoneNumber.get_number_type(telephone) do
  #         :mobile ->
  #           []

  #         _ ->
  #           [telephone: "not a mobile phone number"]
  #       end
  #     else
  #       _ -> [telephone: "invalid mobile phone number"]
  #     end
  #   end)
  # end

  defp verify_telephone(struct_or_changeset, country_code) do
    validate_change(struct_or_changeset, :telephone, fn :telephone, telephone ->
      with {:ok, phone_number} <- ExPhoneNumber.parse(telephone, country_code),
           true <- ExPhoneNumber.is_possible_number?(phone_number),
           true <- ExPhoneNumber.is_valid_number?(phone_number) do
        case ExPhoneNumber.get_number_type(phone_number) do
          :mobile ->
            []

          _ ->
            [telephone: "not a mobile phone number"]
        end
      else
        _ -> [telephone: "invalid phone number"]
      end
    end)
  end

  defp validate_telephone_unique(struct_or_changeset, country_code) do
    validate_change(struct_or_changeset, :telephone, fn :telephone, telephone ->
      with {:ok, phone_number_map} <- ExPhoneNumber.parse(telephone, country_code),
           formatted_telephone_number <- ExPhoneNumber.format(phone_number_map, :e164) do
        case Partners.Access.Profiles.ProfilesContext.manage(
               %{telephone: formatted_telephone_number},
               :get_profile_by_telephone
             ) do
          {:error, :not_found} -> []
          _ -> [telephone: "user with this phone number already exists."]
        end
      else
        _ -> [telephone: "invalid phone number."]
      end
    end)
  end

  defp validate_otp(struct_or_changeset, stored_otp) do
    validate_change(struct_or_changeset, :otp, fn :otp, otp ->
      if String.length(otp) == 6 do
        case otp === stored_otp do
          true ->
            []

          false ->
            [otp: "OTP code does not match."]
        end
      else
        []
      end
    end)
  end

  defp latest_dob_allowed, do: Timex.shift(Timex.today(), years: -@min_age)
  defp earliest_dob_allowed, do: Timex.shift(Timex.today(), years: -@max_age)

  def max_age, do: @max_age
  def min_age, do: @min_age

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

  @doc """
  Changeset for updating a profile's occupation information.
  This is separate from the registration changeset since occupation
  is added after initial registration.
  """
  def occupation_changeset(profile, attrs) do
    profile
    |> cast(attrs, [:occupation_id])
    |> validate_required([:occupation_id])
    |> foreign_key_constraint(:occupation_id)
  end

  ###################################################
  # Changesets for onboarding (registering) new users
  ###################################################

  def registration_username_changeset(struct_or_changeset \\ new(), attrs) do
    struct_or_changeset
    |> cast(attrs, [:username])
    |> validate_username()
  end

  def registration_gender_changeset(struct_or_changeset \\ new(), attrs) do
    struct_or_changeset
    |> cast(attrs, [:gender])
    |> validate_required([:gender])
  end

  def registration_dob_changeset(struct_or_changeset \\ new(), attrs) do
    struct_or_changeset
    |> cast(attrs, [:dob])
    |> validate_required([:dob])
    |> validate_dob_min_age()
    |> validate_dob_max_age()
  end

  def registration_terms_changeset(struct_or_changeset \\ new(), attrs) do
    struct_or_changeset
    |> cast(attrs, [:terms])
    |> validate_required([:terms])
    |> validate_accepted()
  end

  def registration_telephone_changeset(
        struct_or_changeset \\ new(),
        attrs
      ) do
    struct_or_changeset
    |> cast(attrs, [:telephone])
    |> validate_required([:telephone])
    |> validate_length(:telephone, min: 5, max: 13, message: "must be between 5 and 13 digits")
    |> verify_telephone(attrs["country_code"] || "AU")
    |> validate_telephone_unique(attrs["country_code"] || "AU")
  end

  def registration_otp_changeset(struct_or_changeset \\ new(), attrs) do
    struct_or_changeset
    |> cast(attrs, [:otp, :stored_otp])
    |> validate_required([:otp, :stored_otp])
    |> validate_length(:otp, min: 6, max: 6, message: "must be 6 digits")
    |> validate_format(:otp, ~r/^[0-9]+$/, message: "only digits are allowed")
    |> validate_otp(attrs["stored_otp"])
  end

  # End Changesets for onboarding (registering) new users

  ###################################################

  ###################################################
end
