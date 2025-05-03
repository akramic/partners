defmodule Partners.Repo.Migrations.CreateOccupations do
  use Ecto.Migration

  def change do
    create table(:occupations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :category_id, :integer, null: false
      add :group_code, :string, null: false
      add :category, :string, null: false
      add :group, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:occupations, [:group_code])
    create index(:occupations, [:category])
    create unique_index(:occupations, [:group_code, :group])

    # Add occupation_id column to profiles table
    alter table(:profiles) do
      add :occupation_id, references(:occupations, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:profiles, [:occupation_id])
  end
end
