defmodule Partners.Repo.Migrations.CreatePostcodes do
  use Ecto.Migration

  def change do
    create table(:postcodes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :country_code, :string, null: false
      add :postal_code, :string, null: false
      add :place_name, :string, null: false
      add :admin_name1, :string, null: false
      add :admin_code1, :string, null: false
      add :admin_name2, :string
      add :admin_code2, :string
      add :admin_name3, :string
      add :admin_code3, :string
      add :latitude, :float
      add :longitude, :float
      add :accuracy, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:postcodes, [:postal_code])
    create index(:postcodes, [:place_name])
  end
end
