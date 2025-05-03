alias Partners.Repo
alias Partners.Access.Demographics.Occupation
import Ecto.Query

# First, check if there are already occupations in the database
# to make the seed operation idempotent
occupations_count = Repo.aggregate(from(o in Occupation), :count)

if occupations_count == 0 do
  IO.puts("No occupations found in the database. Starting seed process...")

  # Path to the occupations TSV file
  tsv_file_path = Path.join(:code.priv_dir(:partners), "repo/seeds/seed_data/occupation_groups.tsv")

  # Helper function to transform row to occupation struct
  transform_row = fn row ->
    # Convert category_id from string to integer
    category_id = String.to_integer(row["id"])

    %{
      category_id: category_id,
      group_code: row["group-code"],
      category: row["category"],
      group: row["group"],
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  # Read the TSV file with CSV library and process the data
  # Skip the header row
  [_header | data_rows] =
    File.read!(tsv_file_path)
    |> String.split("\n")
    |> Enum.filter(&(String.trim(&1) != ""))

  # Parse each row and prepare for insertion
  occupations =
    data_rows
    |> Enum.map(fn row ->
      # Split by tab
      [id, group_code, category, group] = String.split(row, "\t")

      # Create a map to match the transform_row function
      transform_row.(%{
        "id" => id,
        "group-code" => group_code,
        "category" => category,
        "group" => group
      })
    end)

  # Insert all occupations at once
  {count, _} = Repo.insert_all(Occupation, occupations)
  IO.puts("Inserted #{count} occupations")

  IO.puts("Occupation groups seeding completed!")
else
  IO.puts("Occupations already exist in the database. Skipping seed process.")
end
