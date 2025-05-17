defmodule PartnersWeb.Subscription.SubscriptionHelpers do
  use PartnersWeb, :live_view
  require Logger

  def request_paypal_approval_url(socket) do
    user = socket.assigns.current_scope.user
    trial_plan_id = Partners.Services.Paypal.plan_id()
    user_id = user.id

    Logger.info("🔔 LiveView: Processing PayPal trial creation for user #{user_id}")

    with {:ok, subscription_data} <-
           Partners.Services.Paypal.create_subscription(user.id, trial_plan_id),
         {:ok, subscription_id} <- extract_subscription_id(subscription_data),
         {:ok, approval_url} <- Partners.Services.Paypal.extract_approval_url(subscription_data) do
      Logger.info(
        "🔔 LiveView: Redirecting user #{user_id} to PayPal approval URL (via redirect/2): #{approval_url}"
      )

      socket_with_assigns = assign(socket, subscription_id: subscription_id)

      # Redirect to external URL
      {:noreply, redirect(socket_with_assigns, external: approval_url)}
    else
      {:error, :link_not_found} ->
        # No approval URL from PayPal
        Logger.error("🔔 LiveView: No approval URL from PayPal for user #{user_id}")

        {:noreply,
         assign(socket,
           subscription_status: :failed,
           error_message: "Failed to prepare PayPal: No approval URL received from PayPal.",
           transferring_to_paypal: false
         )}

      {:error, :empty_subscription_id} ->
        Logger.error("🔔 LiveView: Empty subscription ID received from PayPal for user #{user_id}")

        {:noreply,
         assign(socket,
           subscription_status: :failed,
           error_message: "Failed to prepare PayPal: Invalid subscription data received.",
           transferring_to_paypal: false
         )}

      {:error, :subscription_id_not_found} ->
        Logger.error("🔔 LiveView: No subscription ID in PayPal response for user #{user_id}")

        {:noreply,
         assign(socket,
           subscription_status: :failed,
           error_message: "Failed to prepare PayPal: Invalid subscription data received.",
           transferring_to_paypal: false
         )}

      {:error, :invalid_subscription_id_format} ->
        Logger.error("🔔 LiveView: Invalid subscription ID format from PayPal for user #{user_id}")

        {:noreply,
         assign(socket,
           subscription_status: :failed,
           error_message: "Failed to prepare PayPal: Invalid subscription data received.",
           transferring_to_paypal: false
         )}

      {:error, reason} ->
        # Error from PayPal API call
        error_message = extract_error_message(reason)
        Logger.error("🔔 LiveView: PayPal API error for user #{user_id} - #{error_message}")

        {:noreply,
         assign(socket,
           subscription_status: :failed,
           error_message: "Failed to prepare PayPal: #{error_message}",
           transferring_to_paypal: false
         )}
    end
  end

  defp extract_subscription_id(subscription_data) when is_map(subscription_data) do
    case Map.fetch(subscription_data, "id") do
      {:ok, id} when is_binary(id) and id != "" -> {:ok, id}
      {:ok, ""} -> {:error, :empty_subscription_id}
      :error -> {:error, :subscription_id_not_found}
      _ -> {:error, :invalid_subscription_id_format}
    end
  end

  # Helper to extract a friendly error message from PayPal API error responses
  defp extract_error_message(error) when is_map(error) do
    cond do
      # Try to get detailed error message from PayPal response
      get_in(error, ["name"]) ->
        "#{get_in(error, ["name"])}: #{get_in(error, ["message"])}"

      # Fallback for other error structures
      true ->
        inspect(error)
    end
  end

  defp extract_error_message(error), do: inspect(error)
end
