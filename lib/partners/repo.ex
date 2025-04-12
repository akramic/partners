defmodule Partners.Repo do
  use Ecto.Repo,
    otp_app: :partners,
    adapter: Ecto.Adapters.Postgres
end
