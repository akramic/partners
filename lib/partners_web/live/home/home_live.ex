defmodule PartnersWeb.Home.HomeLive do
  use PartnersWeb, :live_view

  alias PartnersWeb.CustomComponents.{Typography, Layout}

  @threshold 2000

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Home")
      |> assign_new(:current_scope, fn -> %{} end)

    # |> put_flash(:success, "Welcome to Phoenix LiveView!")

    {:ok, socket}
  end

  # Handle the event from client to get the IP registry api_key
  @impl true
  def handle_event("get_api_key", %{}, socket) do
    # Send the API key to the client
    {:noreply,
     push_event(socket, "get_api_key", %{
       api_key: get_api_key()
     })}
  end

  # Handle the event when the API call is succssful and data received
  @impl true
  def handle_event(
        "ip_registry_data",
        %{
          "status" => "OK",
          "result" => %{"response" => response, "responseHeaders" => responseHeaders}
        },
        socket
      ) do
    IO.inspect(response, label: "IP Data")
    IO.inspect(responseHeaders, label: "Response Headers")
    maybe_send_admin_email(responseHeaders["ipregistry-credits-remaining"])
    {:noreply, socket}
  end

  # Handle the event when the API call doesn't need to be made - we only receive the stored data in localStorage
  @impl true
  def handle_event("ip_registry_data", %{"status" => "OK", "result" => result}, socket) do
    IO.inspect(result, label: "Response Data")
    {:noreply, socket}
  end

  # Handle the event when the API call is unsuccssful and error received
  def handle_event("ip_registry_data", %{"status" => "error", "result" => error}, socket) do
    # Handle the error case here
    IO.inspect(error)
    {:noreply, socket}
  end

  defp get_api_key(), do: Application.get_env(:partners, :ip_registry_api_key)

  defp maybe_send_admin_email(credits_remaining) do
    [amount, _] = String.split(credits_remaining, "\r")

    if String.to_integer(amount) < @threshold do
      # TODO Send email to admin
      IO.puts("Credits remaining #{amount}. Sending email to admin")
    else
      IO.puts("Credits remaining #{amount}. No need to send email")
    end
  end
end
