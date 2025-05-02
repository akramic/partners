# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Partners.Repo.insert!(%Partners.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Seeds are split into separate files for better organization
# Each seed file can be run independently if needed

# Create the seed_data directory if it doesn't exist
seed_files_dir = Path.join(:code.priv_dir(:partners), "repo/seeds")
File.mkdir_p!(seed_files_dir)

# Create postcodes seed file
postcode_seed_path = Path.join(seed_files_dir, "postcodes.exs")

unless File.exists?(postcode_seed_path) do
  File.write!(postcode_seed_path, """
  alias Partners.Repo
  alias Partners.Access.Demographics.Postcode
  import Ecto.Query, only: [from: 2]

  # Function to convert a string to a float or return nil if conversion fails
  defp safe_float(value) when is_binary(value) and value != "" do
    case Float.parse(value) do
      {float_value, _} -> float_value
      :error -> nil
    end
  end
  defp safe_float(_), do: nil

  # Function to convert a string to an integer or return nil if conversion fails
  defp safe_integer(value) when is_binary(value) and value != "" do
    case Integer.parse(value) do
      {int_value, _} -> int_value
      :error -> nil
    end
  end
  defp safe_integer(_), do: nil

  # First check if there are already postcodes in the database
  # to make the seed operation idempotent
  postcodes_count = Repo.aggregate(from(p in Postcode), :count)

  if postcodes_count == 0 do
    IO.puts("No postcodes found in the database. Starting seed process...")

    # Path to the Australian postcodes TSV file
    tsv_file_path = Path.join(:code.priv_dir(:partners), "repo/seed_data/au.txt")

    # Read and process the TSV file
    File.stream!(tsv_file_path)
    |> Stream.map(&String.trim/1)
    |> Stream.map(&String.split(&1, "\\t"))
    |> Stream.map(fn [country_code, postal_code, place_name, admin_name1, admin_code1,
                     admin_name2, admin_code2, admin_name3, admin_code3,
                     latitude, longitude, accuracy] ->
      %{
        country_code: country_code,
        postal_code: postal_code,
        place_name: place_name,
        admin_name1: admin_name1,
        admin_code1: admin_code1,
        admin_name2: admin_name2 |> (fn s -> if s == "", do: nil, else: s end).(),
        admin_code2: admin_code2 |> (fn s -> if s == "", do: nil, else: s end).(),
        admin_name3: admin_name3 |> (fn s -> if s == "", do: nil, else: s end).(),
        admin_code3: admin_code3 |> (fn s -> if s == "", do: nil, else: s end).(),
        latitude: safe_float(latitude),
        longitude: safe_float(longitude),
        accuracy: safe_integer(accuracy),
        inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
        updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }
    end)
    |> Stream.chunk_every(500) # Insert records in batches of 500
    |> Enum.each(fn batch ->
      Repo.insert_all(Postcode, batch)
      IO.puts("Inserted \#{length(batch)} postcodes")
    end)

    IO.puts("Australian postcodes seeding completed!")
  else
    IO.puts("Postcodes already exist in the database. Skipping seed process.")
  end
  """)
end

# Run each seed file
IO.puts("Running seed files...")

# Load postcodes data
Code.eval_file(postcode_seed_path)

# Add additional seed files here as needed:
# Code.eval_file(Path.join(seed_files_dir, "other_seed_file.exs"))

IO.puts("All seeds completed successfully!")
