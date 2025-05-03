defmodule Partners.Repo.Migrations.AddPostcodeFieldsToProfiles do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      # If a postcode is deleted: All profiles referencing that postcode will have their `postcode_id` set to NULL (nilified)
      add :postcode_id, references(:postcodes, type: :binary_id, on_delete: :nilify_all)
    end

    # Create index on postcode_id for faster lookups
    create index(:profiles, [:postcode_id])

    # Create spatial index for faster location-based lookups
    # This may be redundant if we already have a spatial index on geom
    # Check the existing migration that added geom
    # execute("CREATE INDEX profiles_location_index ON profiles USING gist (geom)")
  end
end
