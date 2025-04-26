defmodule Partners.Repo.Migrations.EnablePostgisExtension do
  use Ecto.Migration

  @moduledoc """
  This migration enables the PostGIS extension for PostgreSQL and adds a
  geometry column to the `profiles` table. The geometry column is used to
  store geographical data, specifically a point with SRID 4326 (WGS 84).
  """

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS postgis"
    execute("SELECT AddGeometryColumn('profiles', 'geom', 4326, 'POINT', 2)")
    execute("CREATE INDEX profiles_point_index on profiles USING gist (geom)")

    flush()
  end

  def down do
    execute("DROP INDEX profiles_point_index")
    execute("SELECT DropGeometryColumn ('profiles','geom')")
    execute "DROP EXTENSION IF EXISTS postgis CASCADE"
  end
end
