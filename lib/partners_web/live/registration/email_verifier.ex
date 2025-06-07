defmodule PartnersWeb.Registration.EmailVerifier do
  import Ecto.Changeset

  @moduledoc """
  Validates email verification results directly on User.email_changeset.

  This module takes an existing User.email_changeset and API response data,
  then applies validation errors directly to the email field of the changeset.

  Responsible only for validation logic - does not handle HTTP requests,
  setting changeset action, or running database operations. It follows the
  single responsibility principle for clean separation of concerns.
  """

  @doc """
  Validates the email in a User.email_changeset against API verification results.

  Returns the User.email_changeset with verification errors added to the email field.

  ## Usage Pattern

  This function is designed to be used in a pipeline with other changeset operations:

  ```elixir
  # In your component
  def verify_email(email_params, socket) do
    # Create the user changeset
    changeset = User.email_changeset(email_params)

    # Call the verification API
    case EmailVerification.verify_email(email) do
      {:ok, response_map} ->
        # Apply verification rules to the changeset
        verified_changeset = EmailVerifier.validate_email(changeset, response_map)

        # Typically proceed with apply_action and handling result
        Ecto.Changeset.apply_action(verified_changeset, :insert)
        |> case do
          {:ok, record} -> # Handle valid case
          {:error, changeset} -> # Handle invalid case
        end

      {:error, reason} ->
        # Handle API error
    end
  end
  ```

  ## Parameters

    * `user_changeset` - An Ecto.Changeset from User.email_changeset
    * `response_map` - Map of response data from the email verification API

  ## Examples

      iex> user_changeset = User.email_changeset(%{"email" => "test@example.com"})
      iex> response_map = %{isDisposable: false, isKnownSpammerDomain: false, isMailServerDefined: true, isSyntaxValid: true, isValid: true}
      iex> EmailVerifier.validate_email(user_changeset, response_map)
      #Ecto.Changeset<...> # Valid changeset with no errors

      iex> user_changeset = User.email_changeset(%{"email" => "invalid@example.com"})
      iex> response_map = %{isDisposable: true, isKnownSpammerDomain: false, isMailServerDefined: false, isSyntaxValid: true, isValid: false}
      iex> EmailVerifier.validate_email(user_changeset, response_map)
      #Ecto.Changeset<...> # Changeset with email validation errors
  """
  @spec validate_email(Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def validate_email(user_changeset, response_map) do
    # Apply each validation check directly to the user changeset
    user_changeset
    |> validate_disposable_email(response_map)
    |> validate_spammer_domain(response_map)
    |> validate_mail_server(response_map)
    |> validate_syntax(response_map)
    |> validate_valid_email(response_map)
  end

  # Individual validation functions that add errors directly to the user changeset

  @spec validate_disposable_email(Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  defp validate_disposable_email(changeset, %{isDisposable: true}),
    do: add_error(changeset, :email, "is a disposable email address")

  defp validate_disposable_email(changeset, _), do: changeset

  @spec validate_spammer_domain(Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  defp validate_spammer_domain(changeset, %{isKnownSpammerDomain: true}),
    do: add_error(changeset, :email, "is from a known spammer domain")

  defp validate_spammer_domain(changeset, _), do: changeset

  @spec validate_mail_server(Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  defp validate_mail_server(changeset, %{isMailServerDefined: false}),
    do: add_error(changeset, :email, "is not associated with a known mail server")

  defp validate_mail_server(changeset, _), do: changeset

  @spec validate_syntax(Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  defp validate_syntax(changeset, %{isSyntaxValid: false}),
    do: add_error(changeset, :email, "has invalid syntax")

  defp validate_syntax(changeset, _), do: changeset

  @spec validate_valid_email(Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  defp validate_valid_email(changeset, %{isValid: false}),
    do: add_error(changeset, :email, "is not a recognised email address")

  defp validate_valid_email(changeset, _), do: changeset
end
