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

IO.puts("Running seed files...")

# Evaluate seed files in order
Code.eval_file("priv/repo/seeds/postcodes.exs")
Code.eval_file("priv/repo/seeds/occupations.exs")

IO.puts("All seeds completed successfully!")

