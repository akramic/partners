alias Partners.Repo
alias Partners.Access.Demographics.Postcode
import Ecto.Query

# First check if there are already postcodes in the database
# to make the seed operation idempotent
postcodes_count = Repo.aggregate(from(p in Postcode), :count)

if postcodes_count == 0 do
  IO.puts("No postcodes found in the database. Starting seed process...")

  # Path to the Australian postcodes TSV file
  tsv_file_path = Path.join(:code.priv_dir(:partners), "repo/seeds/seed_data/au.txt")

  # Helper function to convert empty strings to nil
  empty_string_to_nil = fn
    "" -> nil
    value -> value
  end

  # Helper function to convert values to appropriate types
  transform_row = fn row ->
    # Helper for safely converting to float
    safe_float = fn str ->
      case str do
        "" -> nil
        val ->
          case Float.parse(val) do
            {float_val, _} -> float_val
            :error -> nil
          end
      end
    end

    # Helper for safely converting to integer
    safe_integer = fn str ->
      case str do
        "" -> nil
        val ->
          case Integer.parse(val) do
            {int_val, _} -> int_val
            :error -> nil
          end
      end
    end

    %{
      country_code: row["country code"],
      postal_code: row["postal code"],
      place_name: row["place name"],
      admin_name1: row["admin name1"],
      admin_code1: row["admin code1"],
      admin_name2: row["admin name2"] |> empty_string_to_nil.(),
      admin_code2: row["admin code2"] |> empty_string_to_nil.(),
      admin_name3: row["admin name3"] |> empty_string_to_nil.(),
      admin_code3: row["admin code3"] |> empty_string_to_nil.(),
      latitude: safe_float.(row["latitude"]),
      longitude: safe_float.(row["longitude"]),
      accuracy: safe_integer.(row["accuracy"]),
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  # Read the TSV file with CSV library and process the data
  File.stream!(tsv_file_path)
  |> CSV.decode!(separator: ?\t, headers: [
      "country code", "postal code", "place name", "admin name1", "admin code1",
      "admin name2", "admin code2", "admin name3", "admin code3",
      "latitude", "longitude", "accuracy"
    ])
  |> Stream.map(transform_row)
  |> Stream.chunk_every(500) # Insert records in batches of 500
  |> Enum.each(fn batch ->
    Repo.insert_all(Postcode, batch)
    IO.puts("Inserted #{length(batch)} postcodes")
  end)

  IO.puts("Australian postcodes seeding completed!")
else
  IO.puts("Postcodes already exist in the database. Skipping seed process.")
end
