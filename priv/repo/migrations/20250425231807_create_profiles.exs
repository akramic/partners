defmodule Partners.Repo.Migrations.CreateProfiles do
  use Ecto.Migration

  def change do
    create table(:profiles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :username, :string, null: false
      add :dob, :date, null: false
      add :gender, :string, null: false
      add :marital_status, :string, null: false
      add :terms, :boolean, default: false, null: false
      add :ip_data, :map, null: false
      add :telephone, :string, null: false
      add :video_path, :string
      add :image_path, :string

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:profiles, [:user_id])
    create unique_index(:profiles, [:username])
    create unique_index(:profiles, [:telephone])
  end
end
