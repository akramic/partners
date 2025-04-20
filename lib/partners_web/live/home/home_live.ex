defmodule PartnersWeb.Home.HomeLive do
  use PartnersWeb, :live_view

  alias PartnersWeb.CustomComponents.{Typography, Layout}

  @threshold 2000

  # Region codes ISO 3166-2
  @flags %{
    "AU-NSW" => "New_South_Wales.svg",
    "AU-QLD" => "Queensland.svg",
    "AU-SA" => "South_Australia.svg",
    "AU-TAS" => "Tasmania.svg",
    "AU-VIC" => "Victoria.svg",
    "AU-WA" => "Western_Australia.svg",
    "AU-ACT" => "Australian_Capital_Territory.svg",
    "AU-NT" => "Northern_Territory.svg"
  }

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Home")
      |> assign_new(:current_scope, fn -> %{} end)
      |> stream(:feed, [])
      |> stream_insert(
        :feed,
        %{
          username: "Anon",
          region_name: "Queensland",
          region_code_code: "AU-QLD",
          time_zone: "AEST",
          flag_url: ~p"/images/flags/#{@flags["AU-QLD"]}",
          action: "Viewing",
          id: :os.system_time(:seconds) |> Integer.to_string()
        },
        at: 0
      )

    # |> put_flash(:success, "Welcome to Phoenix LiveView!")
    if connected?(socket) do
      PartnersWeb.Endpoint.subscribe("home")
    end

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

    region_name = response["location"]["region"]["name"]
    region_code = response["location"]["region"]["code"]
    time_zone = response["time_zone"]["abbreviation"]
    flag_url = @flags[region_code]

    maybe_send_admin_email(responseHeaders["ipregistry-credits-remaining"])

    {:noreply, socket}
  end

  # Handle the event when the API call doesn't need to be made - we only receive the stored data in localStorage
  @impl true
  def handle_event("ip_registry_data", %{"status" => "OK", "result" => result}, socket) do
    IO.inspect(result, label: "Response Data")

    socket =
      socket
      |> stream_insert(
        :feed,
        %{
          username: "Areallylongnameherethatgoesonforever",
          region_name: "Queensland",
          region_code_code: "AU-QLD",
          time_zone: "AEST",
          flag_url: ~p"/images/flags/#{@flags["AU-QLD"]}",
          action: "Viewing Now",
          id: :os.system_time(:seconds) |> Integer.to_string()
        },
        at: 0
      )

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

# Response Data: %{
#   "carrier" => %{"mcc" => nil, "mnc" => nil, "name" => nil},
#   "company" => %{
#     "domain" => "wideband.net.au",
#     "name" => "Aussie Broadband",
#     "type" => "isp"
#   },
#   "connection" => %{
#     "asn" => 4764,
#     "domain" => "wideband.net.au",
#     "organization" => "Wideband Networks Pty LTD",
#     "route" => "117.20.68.0/22",
#     "type" => "isp"
#   },
#   "currency" => %{
#     "code" => "AUD",
#     "format" => %{
#       "decimal_separator" => ".",
#       "group_separator" => ",",
#       "negative" => %{"prefix" => "-$", "suffix" => ""},
#       "positive" => %{"prefix" => "$", "suffix" => ""}
#     },
#     "name" => "Australian Dollar",
#     "name_native" => "Australian Dollar",
#     "plural" => "Australian dollars",
#     "plural_native" => "Australian dollars",
#     "symbol" => "A$",
#     "symbol_native" => "$"
#   },
#   "hostname" => nil,
#   "ip" => "117.20.68.135",
#   "location" => %{
#     "city" => "Milton",
#     "continent" => %{"code" => "OC", "name" => "Oceania"},
#     "country" => %{
#       "area" => 7686850,
#       "borders" => [],
#       "calling_code" => "61",
#       "capital" => "Canberra",
#       "code" => "AU",
#       "flag" => %{
#         "emoji" => "🇦🇺",
#         "emoji_unicode" => "U+1F1E6 U+1F1FA",
#         "emojitwo" => "https://cdn.ipregistry.co/flags/emojitwo/au.svg",
#         "noto" => "https://cdn.ipregistry.co/flags/noto/au.png",
#         "twemoji" => "https://cdn.ipregistry.co/flags/twemoji/au.svg",
#         "wikimedia" => "https://cdn.ipregistry.co/flags/wikimedia/au.svg"
#       },
#       "languages" => [
#         %{"code" => "en", "name" => "English", "native" => "English"}
#       ],
#       "name" => "Australia",
#       "population" => 26658948,
#       "population_density" => 3.47,
#       "tld" => ".au"
#     },
#     "in_eu" => false,
#     "language" => %{"code" => "en", "name" => "English", "native" => "English"},
#     "latitude" => -27.47421,
#     "longitude" => 153.0038,
#     "postal" => "4064",
#     "region" => %{"code" => "AU-QLD", "name" => "Queensland"}
#   },
#   "security" => %{
#     "is_abuser" => false,
#     "is_anonymous" => false,
#     "is_attacker" => false,
#     "is_bogon" => false,
#     "is_cloud_provider" => false,
#     "is_proxy" => false,
#     "is_relay" => false,
#     "is_threat" => false,
#     "is_tor" => false,
#     "is_tor_exit" => false,
#     "is_vpn" => false
#   },
#   "time_zone" => %{
#     "abbreviation" => "AEST",
#     "current_time" => "2025-04-20T16:51:45+10:00",
#     "id" => "Australia/Brisbane",
#     "in_daylight_saving" => false,
#     "name" => "Australian Eastern Standard Time",
#     "offset" => 36000
#   },
#   "type" => "IPv4",
#   "user_agent" => %{
#     "device" => %{
#       "brand" => nil,
#       "name" => "Linux Desktop",
#       "type" => "desktop"
#     },
#     "engine" => %{
#       "name" => "Gecko",
#       "type" => "browser",
#       "version" => "137.0",
#       "version_major" => "137"
#     },
#     "header" => "Mozilla/5.0 (X11; Linux x86_64; rv:137.0) Gecko/20100101 Firefox/137.0",
#     "name" => "Firefox",
#     "os" => %{"name" => "Linux", "type" => "desktop", "version" => nil},
#     "type" => "browser",
#     "version" => "137.0",
#     "version_major" => "137"
#   }
# }
