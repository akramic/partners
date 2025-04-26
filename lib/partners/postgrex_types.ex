# https://hexdocs.pm/geo_postgis/readme.html

Postgrex.Types.define(
  Partners.PostgresTypes,
  [Geo.PostGIS.Extension] ++ Ecto.Adapters.Postgres.extensions(),
  json: Jason
)
