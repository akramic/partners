defmodule Partners.Access.Profiles.ProfilesContext do
  @moduledoc """
  Context module for profile-related operations.

  This module implements the ContextBehaviour interface specifically for
  profile-related operations. It serves as a domain boundary for interactions
  with profiles in the system.

  ## Usage Examples

  The ProfilesContext provides a consistent interface for all profile operations,
  simplifying client code and enforcing business rules. Here are examples showing
  how to use this module in different contexts:  ### User Registration and Profile Creation

  ```elixir
  # In a LiveView or controller handling registration
  def handle_event("register", %{"user" => user_params, "profile" => profile_params}, socket) do
    # Create user with nested profile in a single operation
    combined_params = Map.put(user_params, "profile", profile_params)

    case Partners.Accounts.create_user(combined_params) do
      {:ok, %{profile: profile} = user} ->
        {:noreply, assign(socket, :current_user, user, :current_profile, profile)}

      {:error, changeset} ->
        {:noreply, assign(socket, :errors, format_errors(changeset))}
    end
  end
  ```

  ### Profile Data Retrieval

  ```elixir
  # Get a profile by user ID
  def mount(%{"user_id" => user_id}, _session, socket) do
    case ProfilesContext.manage(%{user_id: user_id}, :get_profile_by_user_id) do
      {:ok, profile} ->
        {:ok, assign(socket, :profile, profile)}

      {:error, :not_found} ->
        {:ok, redirect(socket, to: ~p"/profiles/new")}
    end
  end
  ```

  ### Profile Location Updates

  ```elixir
  # In a LiveView or controller handling location updates
  def handle_event("update_location", %{"postcode" => postcode_id, "place_name" => place_name}, socket) do
    location_attrs = %{postcode_id: postcode_id, place_name: place_name}

    case ProfilesContext.manage(
      %{profile: socket.assigns.profile, attrs: location_attrs},
      :update_profile_location
    ) do
      {:ok, updated_profile} ->
        {:noreply, assign(socket, :profile, updated_profile)}

      {:error, _error} ->
        {:noreply, assign(socket, :error, "Failed to update location")}
    end
  end
  ```

  ### Location-Based Profile Search

  ```elixir
  # In a LiveView or controller handling nearby profile search
  def handle_event("find_nearby", %{"distance" => distance}, socket) do
    # Get current user's profile location
    {:ok, profile} = ProfilesContext.manage(%{user_id: socket.assigns.current_user_id}, :get_profile_by_user_id)

    # Search for profiles near the current user
    search_params = %{
      longitude: profile.geom.coordinates |> elem(0),
      latitude: profile.geom.coordinates |> elem(1),
      distance: String.to_integer(distance)
    }

    case ProfilesContext.manage(search_params, :find_profiles_near_location) do
      {:ok, {count, nearby_profiles}} ->
        {:noreply, assign(socket, nearby_profiles: nearby_profiles, match_count: count)}

      {:error, :no_profiles_found} ->
        {:noreply, assign(socket, nearby_profiles: [], match_count: 0)}
    end
  end
  ```

  ### Advanced Profile Filtering

  ```elixir
  # Implementing a complex profile search
  def search_profiles(params) do
    # Build search criteria based on user input
    criteria = %{}

    # Add gender filter if provided
    criteria = if params["gender"], do: Map.put(criteria, :gender, String.to_atom(params["gender"])), else: criteria

    # Add marital status filter if provided
    criteria = if params["marital_status"],
      do: Map.put(criteria, :marital_status, String.to_atom(params["marital_status"])),
      else: criteria

    # Add age range filter if provided
    criteria = if params["min_age"] && params["max_age"],
      do: Map.put(criteria, :age_range, {String.to_integer(params["min_age"]), String.to_integer(params["max_age"])}),
      else: criteria

    # Add occupation filter if provided
    criteria = if params["occupation_id"],
      do: Map.put(criteria, :occupation_id, params["occupation_id"]),
      else: criteria

    # Add location filter if all location params are provided
    criteria = if params["longitude"] && params["latitude"] && params["distance"],
      do: Map.put(criteria, :near_point, {
        String.to_float(params["longitude"]),
        String.to_float(params["latitude"]),
        String.to_integer(params["distance"])
      }),
      else: criteria

    # Add pagination
    criteria = Map.merge(criteria, %{
      limit: Map.get(params, "limit", 20),
      offset: Map.get(params, "offset", 0),
      order_by: {:username, :asc}
    })

    # Include related data
    criteria = Map.put(criteria, :includes, [:postcode, :occupation])

    # Perform the search
    {count, profiles} = ProfilesContext.manage(criteria, :search_profiles)

    # Format the response
    %{
      total: count,
      profiles: profiles,
      page: div(Map.get(criteria, :offset, 0), Map.get(criteria, :limit, 20)) + 1,
      total_pages: ceil(count / Map.get(criteria, :limit, 20))
    }
  end
  ```

  These examples illustrate how the ProfilesContext module provides a flexible and
  composable interface for working with profile data in various scenarios, from simple
  CRUD operations to complex queries with multiple filtering criteria.
  """
  @behaviour Partners.Access.Behaviour.ContextBehaviour

  require Logger
  alias Partners.Access.Profiles.ProfilesAccess

  # Use the access module directly
  @profile_access ProfilesAccess

  @impl Partners.Access.Behaviour.ContextBehaviour
  @doc """
  Perform a domain operation related to profiles.

  This is the primary entry point for all profile-related business logic. Each operation
  is represented by an atom as the second parameter, and the attributes contain the data
  needed for that specific operation.

  ## Common Operations

  * `:create_profile` - Create a new profile
  * `:update_profile` - Update an existing profile
  * `:get_profile_by_user_id` - Get a profile by user ID
  * `:search_profiles` - Search for profiles with various criteria
  * `:update_profile_location` - Update a profile's location information
  * `:update_profile_occupation` - Update a profile's occupation

  ## Parameters

    * `attrs` - Map of attributes required for the specific operation
    * `operation` - Atom representing the operation to perform

  ## Returns

    * `{:ok, term()}` - Operation result on success
    * `{:error, error()}` - Error information on failure
  """
  # Creates a new profile.
  #
  # This operation stores a new profile in the database using the registration changeset.
  #
  # Parameters:
  #   * `attrs` - Map of profile attributes matching the Profile schema
  #
  # Returns:
  #   * `{:ok, profile}` - The created profile on success
  #   * `{:error, changeset}` - Changeset with errors on failure
  #
  # Example:
  #
  #     ProfilesContext.manage(%{
  #       username: "johndoe",
  #       dob: ~D[1990-01-01],
  #       gender: :Male,
  #       marital_status: :Single,
  #       terms: true,
  #       ip_data: %{},
  #       telephone: "+1234567890"
  #     }, :create_profile)
  def manage(attrs, :create_profile) do
    @profile_access.store(attrs, :profile)
  end

  @impl Partners.Access.Behaviour.ContextBehaviour
  # Updates an existing profile.
  #
  # This operation updates an existing profile with new attributes.
  #
  # Parameters:
  #   * `attrs` - Map containing:
  #     * `:profile` - The existing Profile struct to update
  #     * `:attrs` - Map of new profile attributes
  #
  # Returns:
  #   * `{:ok, profile}` - The updated profile on success
  #   * `{:error, changeset}` - Changeset with errors on failure
  #
  # Example:
  #
  #     ProfilesContext.manage(%{
  #       profile: existing_profile,
  #       attrs: %{username: "johndoe_updated"}
  #     }, :update_profile)
  def manage(attrs, :update_profile) do
    %{profile: profile, attrs: update_attrs} = attrs

    @profile_access.store(update_attrs, profile)
  end

  @impl Partners.Access.Behaviour.ContextBehaviour
  # Gets a profile by ID.
  #
  # This operation retrieves a profile by its unique identifier.
  #
  # Parameters:
  #   * `attrs` - Map containing:
  #     * `:id` - The UUID of the profile to retrieve
  #
  # Returns:
  #   * `{:ok, profile}` - The profile if found
  #   * `{:error, :not_found}` - If no profile matches the ID
  #
  # Example:
  #
  #     ProfilesContext.manage(%{id: "12345678-1234-1234-1234-123456789012"}, :get_profile)
  def manage(attrs, :get_profile) do
    %{id: id} = attrs

    @profile_access.load(%{id: id}, :profile)
  end

  @impl Partners.Access.Behaviour.ContextBehaviour
  # Gets a profile by user ID.
  #
  # This operation retrieves a profile associated with a specific user.
  #
  # Parameters:
  #   * `attrs` - Map containing:
  #     * `:user_id` - The UUID of the user whose profile to retrieve
  #
  # Returns:
  #   * `{:ok, profile}` - The profile if found
  #   * `{:error, :not_found}` - If no profile matches the user ID
  #
  # Example:
  #
  #     ProfilesContext.manage(%{user_id: "12345678-1234-1234-1234-123456789012"}, :get_profile_by_user_id)
  def manage(attrs, :get_profile_by_user_id) do
    %{user_id: user_id} = attrs

    @profile_access.load(%{user_id: user_id}, :profile)
  end

  @impl Partners.Access.Behaviour.ContextBehaviour
  # Gets a profile by username.
  #
  # This operation retrieves a profile by its username.
  #
  # Parameters:
  #   * `attrs` - Map containing:
  #     * `:username` - The username of the profile to retrieve
  #
  # Returns:
  #   * `{:ok, profile}` - The profile if found
  #   * `{:error, :not_found}` - If no profile matches the username
  #
  # Example:
  #
  #     ProfilesContext.manage(%{username: "johndoe"}, :get_profile_by_username)
  def manage(attrs, :get_profile_by_username) do
    %{username: username} = attrs

    @profile_access.load(%{username: username}, :profile)
  end

  @impl Partners.Access.Behaviour.ContextBehaviour
  # Deletes a profile.
  #
  # This operation removes a profile from the database.
  #
  # Parameters:
  #   * `attrs` - Map containing:
  #     * `:id` - The UUID of the profile to delete
  #
  # Returns:
  #   * `{:ok, profile}` - The deleted profile on success
  #   * `{:error, reason}` - Error information on failure
  #
  # Example:
  #
  #     ProfilesContext.manage(%{id: "12345678-1234-1234-1234-123456789012"}, :delete_profile)
  def manage(attrs, :delete_profile) do
    %{id: id} = attrs

    @profile_access.remove(%{id: id}, :profile)
  end

  @impl Partners.Access.Behaviour.ContextBehaviour
  # Updates a profile's location information.
  #
  # This operation updates a profile's location data and automatically
  # calculates and sets the geographic point (geom) based on the postcode.
  #
  # Parameters:
  #   * `attrs` - Map containing:
  #     * `:profile` - The existing Profile struct to update
  #     * `:attrs` - Map of location attributes (postcode_id, place_name)
  #
  # Returns:
  #   * `{:ok, profile}` - The updated profile on success
  #   * `{:error, reason}` - Error information on failure
  #
  # Example:
  #
  #     ProfilesContext.manage(%{
  #       profile: existing_profile,
  #       attrs: %{postcode_id: "postcode-uuid", place_name: "Brisbane"}
  #     }, :update_profile_location)
  def manage(attrs, :update_profile_location) do
    %{profile: profile, attrs: location_attrs} = attrs

    @profile_access.update_location(profile, location_attrs)
  end

  @impl Partners.Access.Behaviour.ContextBehaviour
  # Updates a profile's occupation information.
  #
  # This operation updates a profile's occupation data.
  #
  # Parameters:
  #   * `attrs` - Map containing:
  #     * `:profile` - The existing Profile struct to update
  #     * `:attrs` - Map of occupation attributes (occupation_id)
  #
  # Returns:
  #   * `{:ok, profile}` - The updated profile on success
  #   * `{:error, changeset}` - Changeset with errors on failure
  #
  # Example:
  #
  #     ProfilesContext.manage(%{
  #       profile: existing_profile,
  #       attrs: %{occupation_id: "occupation-uuid"}
  #     }, :update_profile_occupation)
  def manage(attrs, :update_profile_occupation) do
    %{profile: profile, attrs: occupation_attrs} = attrs

    @profile_access.update_occupation(profile, occupation_attrs)
  end

  @impl Partners.Access.Behaviour.ContextBehaviour
  # Updates a profile's image path.
  #
  # This operation updates the path to a profile's image.
  #
  # Parameters:
  #   * `attrs` - Map containing:
  #     * `:profile` - The existing Profile struct to update
  #     * `:image_path` - String representing the path to the profile image
  #
  # Returns:
  #   * `{:ok, profile}` - The updated profile on success
  #   * `{:error, changeset}` - Changeset with errors on failure
  #
  # Example:
  #
  #     ProfilesContext.manage(%{
  #       profile: existing_profile,
  #       image_path: "/uploads/profiles/avatar123.jpg"
  #     }, :update_profile_image)
  def manage(attrs, :update_profile_image) do
    %{profile: profile, image_path: image_path} = attrs

    @profile_access.update_image(profile, image_path)
  end

  @impl Partners.Access.Behaviour.ContextBehaviour
  # Updates a profile's video path.
  #
  # This operation updates the path to a profile's video.
  #
  # Parameters:
  #   * `attrs` - Map containing:
  #     * `:profile` - The existing Profile struct to update
  #     * `:video_path` - String representing the path to the profile video
  #
  # Returns:
  #   * `{:ok, profile}` - The updated profile on success
  #   * `{:error, changeset}` - Changeset with errors on failure
  #
  # Example:
  #
  #     ProfilesContext.manage(%{
  #       profile: existing_profile,
  #       video_path: "/uploads/profiles/intro123.mp4"
  #     }, :update_profile_video)
  def manage(attrs, :update_profile_video) do
    %{profile: profile, video_path: video_path} = attrs

    @profile_access.update_video(profile, video_path)
  end

  @impl Partners.Access.Behaviour.ContextBehaviour
  # Searches for profiles based on various criteria.
  #
  # This operation allows complex filtering of profiles based on multiple criteria.
  #
  # Parameters:
  #   * `attrs` - Map containing any combination of filter criteria:
  #     * `:gender` - Filter by gender (e.g., :Male, :Female)
  #     * `:marital_status` - Filter by marital status
  #     * `:age_range` - Filter by age range as tuple {min_age, max_age}
  #     * `:near_point` - Filter by proximity to point {longitude, latitude, distance_in_meters}
  #     * `:occupation_id` - Filter by occupation ID
  #     * `:limit` - Number of records to return (default 100)
  #     * `:offset` - Offset for pagination (default 0)
  #     * `:order_by` - Ordering criteria (e.g., :username, {:username, :asc})
  #     * `:includes` - List of associations to preload (e.g., [:postcode, :occupation])
  #
  # Returns:
  #   * `{count, profiles}` - Tuple with count of matching records and the records themselves
  #
  # Example:
  #
  #     # Simple search with a single criterion
  #     ProfilesContext.manage(%{gender: :Female}, :search_profiles)
  #
  #     # Complex search with multiple criteria
  #     ProfilesContext.manage(%{
  #       gender: :Male,
  #       marital_status: :Single,
  #       age_range: {25, 35},
  #       near_point: {153.0251, -27.4698, 5000},
  #       limit: 10,
  #       offset: 0,
  #       order_by: :username,
  #       includes: [:postcode, :occupation]
  #     }, :search_profiles)
  def manage(attrs, :search_profiles) do
    @profile_access.filter(attrs, :profile)
  end

  @impl Partners.Access.Behaviour.ContextBehaviour
  # Finds profiles by gender.
  #
  # This operation searches for profiles with a specific gender.
  #
  # Parameters:
  #   * `attrs` - Map containing:
  #     * `:gender` - The gender to filter by (e.g., :Male, :Female)
  #
  # Returns:
  #   * `{:ok, {count, profiles}}` - Tuple with count and profiles on success
  #   * `{:error, :no_profiles_found}` - If no matching profiles are found
  #
  # Example:
  #
  #     ProfilesContext.manage(%{gender: :Female}, :find_profiles_by_gender)
  def manage(attrs, :find_profiles_by_gender) do
    %{gender: gender} = attrs

    {count, profiles} = @profile_access.filter(%{gender: gender}, :profile)

    if profiles == [] do
      {:error, :no_profiles_found}
    else
      {:ok, {count, profiles}}
    end
  end

  @impl Partners.Access.Behaviour.ContextBehaviour
  # Finds profiles by marital status.
  #
  # This operation searches for profiles with a specific marital status.
  #
  # Parameters:
  #   * `attrs` - Map containing:
  #     * `:marital_status` - The marital status to filter by (e.g., :Single, :Divorced)
  #
  # Returns:
  #   * `{:ok, {count, profiles}}` - Tuple with count and profiles on success
  #   * `{:error, :no_profiles_found}` - If no matching profiles are found
  #
  # Example:
  #
  #     ProfilesContext.manage(%{marital_status: :Single}, :find_profiles_by_marital_status)
  def manage(attrs, :find_profiles_by_marital_status) do
    %{marital_status: marital_status} = attrs

    {count, profiles} = @profile_access.filter(%{marital_status: marital_status}, :profile)

    if profiles == [] do
      {:error, :no_profiles_found}
    else
      {:ok, {count, profiles}}
    end
  end

  @impl Partners.Access.Behaviour.ContextBehaviour
  # Finds profiles by age range.
  #
  # This operation searches for profiles with ages falling within a specific range.
  #
  # Parameters:
  #   * `attrs` - Map containing:
  #     * `:min_age` - The minimum age in years
  #     * `:max_age` - The maximum age in years
  #
  # Returns:
  #   * `{:ok, {count, profiles}}` - Tuple with count and profiles on success
  #   * `{:error, :no_profiles_found}` - If no matching profiles are found
  #
  # Example:
  #
  #     ProfilesContext.manage(%{min_age: 25, max_age: 35}, :find_profiles_by_age_range)
  def manage(attrs, :find_profiles_by_age_range) do
    %{min_age: min_age, max_age: max_age} = attrs

    {count, profiles} = @profile_access.filter(%{age_range: {min_age, max_age}}, :profile)

    if profiles == [] do
      {:error, :no_profiles_found}
    else
      {:ok, {count, profiles}}
    end
  end

  @impl Partners.Access.Behaviour.ContextBehaviour
  # Finds profiles near a geographic location.
  #
  # This operation searches for profiles within a certain distance of a geographic point.
  #
  # Parameters:
  #   * `attrs` - Map containing:
  #     * `:longitude` - The longitude coordinate of the center point
  #     * `:latitude` - The latitude coordinate of the center point
  #     * `:distance` - The search radius in meters
  #
  # Returns:
  #   * `{:ok, {count, profiles}}` - Tuple with count and profiles on success
  #   * `{:error, :no_profiles_found}` - If no matching profiles are found
  #
  # Example:
  #
  #     # Find profiles within 5km of Brisbane CBD
  #     ProfilesContext.manage(%{
  #       longitude: 153.0251,
  #       latitude: -27.4698,
  #       distance: 5000
  #     }, :find_profiles_near_location)
  def manage(attrs, :find_profiles_near_location) do
    %{longitude: longitude, latitude: latitude, distance: distance} = attrs

    {count, profiles} =
      @profile_access.filter(%{near_point: {longitude, latitude, distance}}, :profile)

    if profiles == [] do
      {:error, :no_profiles_found}
    else
      {:ok, {count, profiles}}
    end
  end

  @impl Partners.Access.Behaviour.ContextBehaviour
  # Finds profiles with associated data preloaded.
  #
  # This operation searches for profiles with specified criteria and preloads
  # related data such as postcode and occupation records.
  #
  # Parameters:
  #   * `attrs` - Map containing:
  #     * `:includes` - List of associations to preload (e.g., [:postcode, :occupation])
  #     * Additional filtering criteria as needed
  #
  # Returns:
  #   * `{:ok, {count, profiles}}` - Tuple with count and profiles on success
  #   * `{:error, :no_profiles_found}` - If no matching profiles are found
  #
  # Example:
  #
  #     # Find female profiles and include their postcode and occupation data
  #     ProfilesContext.manage(%{
  #       gender: :Female,
  #       includes: [:postcode, :occupation]
  #     }, :find_profiles_with_includes)
  def manage(attrs, :find_profiles_with_includes) do
    %{includes: includes} = attrs

    criteria = Map.put(Map.delete(attrs, :includes), :includes, includes)
    {count, profiles} = @profile_access.filter(criteria, :profile)

    if profiles == [] do
      {:error, :no_profiles_found}
    else
      {:ok, {count, profiles}}
    end
  end
end
