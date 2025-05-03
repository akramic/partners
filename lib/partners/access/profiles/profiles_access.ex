defmodule Partners.Access.Profiles.ProfilesAccess do
  @moduledoc """
  Access module for Profile schema.

  Implements the AccessBehaviour interface for the Profile schema, providing
  standardized methods for storing, filtering, removing, and loading profile data.

  This module serves as the data access layer for profile-related operations,
  encapsulating all database interactions with the Profile schema. It provides a
  consistent and reusable interface for CRUD operations, allowing the application
  to interact with profile data without directly coupling to database specifics.

  The module implements four primary operations:
  - `store/2`: Create or update profile records
  - `filter/2`: Query profiles with flexible filtering criteria
  - `remove/2`: Delete profile records
  - `load/2`: Fetch profile records by specific criteria

  Additionally, it provides specialized methods for updating specific aspects of profiles
  such as location, occupation, image, and video.
  """
  @behaviour Partners.Access.Behaviour.AccessBehaviour

  import Ecto.Query
  alias Partners.Repo
  alias Partners.Access.Profiles.Profile

  @impl true
  @doc """
  Store a profile record in the database.

  Creates a new profile when given `:profile` as the second parameter,
  or updates an existing profile when given a Profile struct.

  ## Parameters

    * `attrs` - Map of attributes to store
    * `schema` - Either the atom `:profile` or an existing Profile struct

  ## Returns

    * `{:ok, profile}` - The stored profile on success
    * `{:error, changeset}` - Changeset with errors on failure

  ## Examples

      # Create a new profile
      {:ok, profile} = ProfilesAccess.store(%{
        username: "johndoe",
        dob: ~D[1990-01-01],
        gender: :Male,
        marital_status: :Single,
        terms: true,
        ip_data: %{},
        telephone: "+1234567890"
      }, :profile)

      # Update an existing profile
      {:ok, updated_profile} = ProfilesAccess.store(%{
        username: "johndoe_updated"
      }, existing_profile)
  """
  def store(attrs, :profile) do
    %Profile{}
    |> Profile.registration_changeset(attrs)
    |> Repo.insert()
  end

  # Update an existing profile with new attributes.
  #
  # This is an overloaded version of the `store/2` function that handles
  # updates to existing profile records.
  #
  # Parameters:
  #   * `attrs` - Map of attributes to update
  #   * `profile` - Existing Profile struct to update
  #
  # Returns:
  #   * `{:ok, profile}` - The updated profile on success
  #   * `{:error, changeset}` - Changeset with errors on failure
  def store(attrs, %Profile{} = profile) do
    profile
    |> Profile.registration_changeset(attrs)
    |> Repo.update()
  end

  @impl true
  @doc """
  Filter profiles based on criteria.

  This function provides a composable query interface where different criteria can be combined
  to create powerful, flexible queries for profile data. It transforms a map of criteria into
  an Ecto query, executes it, and returns both the matching records and their count.

  ## Parameters

    * `criteria` - Map of filtering criteria, which can include:
      * `{:username, username}` - Filter by exact username match
      * `{:gender, gender}` - Filter by gender (e.g., :Male, :Female)
      * `{:marital_status, status}` - Filter by marital status
      * `{:postcode_id, id}` - Filter by postcode ID
      * `{:occupation_id, id}` - Filter by occupation ID
      * `{:user_id, id}` - Filter by user ID
      * `{:username_like, pattern}` - Filter by username starting with pattern
      * `{:age_range, {min_age, max_age}}` - Filter by age range
      * `{:near_point, {longitude, latitude, distance}}` - Filter by geographic proximity
      * `{:select, fields}` - Select only specific fields
      * `{:includes, associations}` - Preload associations
      * `{:limit, limit}` - Limit number of results
      * `{:offset, offset}` - Pagination offset
      * `{:order_by, field}` - Order by field
      * `{:order_by, {field, direction}}` - Order by field with direction

    * `schema` - Atom representing the schema type (always `:profile` for this function)

  ## Returns

    * `{count, profiles}` - Tuple with count of matching records and the records themselves

  ## Examples

      # Find all female profiles aged 25-35
      {count, profiles} = ProfilesAccess.filter(
        %{
          gender: :Female,
          age_range: {25, 35}
        },
        :profile
      )

      # Find profiles near a location with pagination
      {count, profiles} = ProfilesAccess.filter(
        %{
          near_point: {longitude, latitude, 5000}, # 5km radius
          limit: 10,
          offset: 20,
          order_by: :username
        },
        :profile
      )
  """
  def filter(criteria, :profile) do
    query = from p in Profile, as: :profile

    query =
      Enum.reduce(criteria, query, fn
        {:username, username}, query ->
          from [profile: p] in query, where: p.username == ^username

        {:gender, gender}, query ->
          from [profile: p] in query, where: p.gender == ^gender

        {:marital_status, marital_status}, query ->
          from [profile: p] in query, where: p.marital_status == ^marital_status

        {:postcode_id, postcode_id}, query ->
          from [profile: p] in query, where: p.postcode_id == ^postcode_id

        {:occupation_id, occupation_id}, query ->
          from [profile: p] in query, where: p.occupation_id == ^occupation_id

        {:user_id, user_id}, query ->
          from [profile: p] in query, where: p.user_id == ^user_id

        {:username_like, pattern}, query ->
          from [profile: p] in query, where: like(p.username, ^"#{pattern}%")

        {:age_range, {min_age, max_age}}, query ->
          min_date = Date.add(Date.utc_today(), -max_age * 365)
          max_date = Date.add(Date.utc_today(), -min_age * 365)
          from [profile: p] in query, where: p.dob >= ^min_date and p.dob <= ^max_date

        {:near_point, {longitude, latitude, distance}}, query ->
          point = %Geo.Point{coordinates: {longitude, latitude}, srid: 4326}

          from [profile: p] in query,
            where:
              fragment("ST_DWithin(?::geography, ?::geography, ?)", p.geom, ^point, ^distance),
            order_by: fragment("ST_Distance(?::geography, ?::geography)", p.geom, ^point)

        {:select, fields}, query when is_list(fields) ->
          from [profile: p] in query, select: map(p, ^fields)

        {:includes, includes}, query when is_list(includes) ->
          from [profile: p] in query, preload: ^includes

        {:limit, limit}, query ->
          from [profile: p] in query, limit: ^limit

        {:offset, offset}, query ->
          from [profile: p] in query, offset: ^offset

        {:order_by, {field, direction}}, query ->
          from [profile: p] in query, order_by: [{^direction, field(p, ^field)}]

        {:order_by, field}, query ->
          from [profile: p] in query, order_by: field(p, ^field)

        _, query ->
          query
      end)

    {Repo.aggregate(query, :count), Repo.all(query)}
  end

  @impl true
  @doc """
  Remove a profile record from the database.

  This function first loads the profile using the provided criteria,
  then deletes it if a single record is found.

  ## Parameters

    * `criteria` - Map of criteria to identify the profile to remove
    * `schema` - Atom representing the schema type (always `:profile` for this function)

  ## Returns

    * `{:ok, profile}` - The deleted profile on success
    * `{:error, reason}` - Error information on failure

  ## Examples

      # Delete a profile by ID
      {:ok, deleted_profile} = ProfilesAccess.remove(%{id: profile_id}, :profile)

      # This will fail if multiple profiles would match the criteria
      {:error, reason} = ProfilesAccess.remove(%{gender: :Male}, :profile)
  """
  def remove(criteria, :profile) do
    case load(criteria, :profile) do
      {:ok, profile} when is_map(profile) and not is_list(profile) ->
        Repo.delete(profile)

      {:ok, _profiles} ->
        {:error, "Cannot remove multiple profiles with this operation"}

      error ->
        error
    end
  end

  @impl true
  @doc """
  Load profile records by specific criteria.

  This function builds a query based on the provided criteria and returns
  the matching profile record(s).

  ## Parameters

    * `criteria` - Map of criteria to identify the profile(s) to load, which can include:
      * `{:id, id}` - Find by profile ID
      * `{:username, username}` - Find by exact username match
      * `{:user_id, id}` - Find by user ID
      * `{:includes, associations}` - Preload specified associations

    * `schema` - Atom representing the schema type (always `:profile` for this function)

  ## Returns

    * `{:ok, profile}` - A single matching profile
    * `{:ok, profiles}` - List of matching profiles
    * `{:error, :not_found}` - No matching profiles found

  ## Examples

      # Load a profile by ID
      {:ok, profile} = ProfilesAccess.load(%{id: profile_id}, :profile)

      # Load a profile with associations preloaded
      {:ok, profile} = ProfilesAccess.load(%{
        id: profile_id,
        includes: [:user, :postcode, :occupation]
      }, :profile)
  """
  def load(criteria, :profile) do
    query = from p in Profile, as: :profile

    query =
      Enum.reduce(criteria, query, fn
        {:id, id}, query ->
          from [profile: p] in query, where: p.id == ^id

        {:username, username}, query ->
          from [profile: p] in query, where: p.username == ^username

        {:user_id, user_id}, query ->
          from [profile: p] in query, where: p.user_id == ^user_id

        {:includes, includes}, query ->
          from [profile: p] in query, preload: ^includes

        _, query ->
          query
      end)

    query
    |> Repo.all()
    |> case do
      [] -> {:error, :not_found}
      [profile] -> {:ok, profile}
      [_ | _] = profiles -> {:ok, profiles}
    end
  end

  @doc """
  Update a profile's location information.

  This specialized function uses the Profile module's update_location function,
  which handles both updating location attributes and calculating the geom field.

  ## Parameters

    * `profile` - Existing Profile struct to update
    * `attrs` - Map containing location attributes (postcode_id, place_name)

  ## Returns

    * `{:ok, profile}` - The updated profile on success
    * `{:error, reason}` - Error information on failure
  """
  def update_location(profile, attrs) do
    Profile.update_location(profile, attrs)
  end

  @doc """
  Update a profile's occupation information.

  This specialized function uses the Profile module's occupation_changeset
  to validate and update the occupation relationship.

  ## Parameters

    * `profile` - Existing Profile struct to update
    * `attrs` - Map containing occupation attributes (occupation_id)

  ## Returns

    * `{:ok, profile}` - The updated profile on success
    * `{:error, changeset}` - Changeset with errors on failure
  """
  def update_occupation(profile, attrs) do
    profile
    |> Profile.occupation_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Update a profile's image path.

  This function allows updating just the image_path field of a profile.

  ## Parameters

    * `profile` - Existing Profile struct to update
    * `image_path` - String representing the path to the profile image

  ## Returns

    * `{:ok, profile}` - The updated profile on success
    * `{:error, changeset}` - Changeset with errors on failure
  """
  def update_image(profile, image_path) do
    profile
    |> Ecto.Changeset.change(image_path: image_path)
    |> Repo.update()
  end

  @doc """
  Update a profile's video path.

  This function allows updating just the video_path field of a profile.

  ## Parameters

    * `profile` - Existing Profile struct to update
    * `video_path` - String representing the path to the profile video

  ## Returns

    * `{:ok, profile}` - The updated profile on success
    * `{:error, changeset}` - Changeset with errors on failure
  """
  def update_video(profile, video_path) do
    profile
    |> Ecto.Changeset.change(video_path: video_path)
    |> Repo.update()
  end
end
