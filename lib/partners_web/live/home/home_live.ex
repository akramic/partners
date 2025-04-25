defmodule PartnersWeb.Home.HomeLive do
  use PartnersWeb, :live_view

  alias PartnersWeb.CustomComponents.{Typography, Layout}

  @threshold 2000

  # Region codes ISO 3166-2 with associated data
  @australian_regions %{
    "AU-NSW" => %{
      flag: "New_South_Wales.svg",
      name: "New South Wales",
      # Australian Eastern Standard Time
      time_zone: "AEST"
    },
    "AU-QLD" => %{
      flag: "Queensland.svg",
      name: "Queensland",
      # Australian Eastern Standard Time
      time_zone: "AEST"
    },
    "AU-SA" => %{
      flag: "South_Australia.svg",
      name: "South Australia",
      # Australian Central Standard Time
      time_zone: "ACST"
    },
    "AU-TAS" => %{
      flag: "Tasmania.svg",
      name: "Tasmania",
      # Australian Eastern Standard Time
      time_zone: "AEST"
    },
    "AU-VIC" => %{
      flag: "Victoria.svg",
      name: "Victoria",
      # Australian Eastern Standard Time
      time_zone: "AEST"
    },
    "AU-WA" => %{
      flag: "Western_Australia.svg",
      name: "Western Australia",
      # Australian Western Standard Time
      time_zone: "AWST"
    },
    "AU-ACT" => %{
      flag: "Australian_Capital_Territory.svg",
      name: "Australian Capital Territory",
      # Australian Eastern Standard Time
      time_zone: "AEST"
    },
    "AU-NT" => %{
      flag: "Northern_Territory.svg",
      name: "Northern Territory",
      # Australian Central Standard Time
      time_zone: "ACST"
    }
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok, timer_ref} = :timer.send_interval(8000, self(), :tick)

    socket =
      socket
      |> assign(page_title: "Home")
      |> assign_new(:current_scope, fn -> %{} end)
      |> stream(:feed, [])
      |> assign(timer_ref: timer_ref)
      # |> put_flash(:warning, "Welcome to Phoenix LiveView!")

    if connected?(socket) do
      PartnersWeb.Endpoint.subscribe("home_feed")
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    # Handle the params here if needed
    {:noreply, socket}
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
    region_name = response["location"]["region"]["name"]
    region_code = response["location"]["region"]["code"]
    time_zone = response["time_zone"]["abbreviation"]

    # Broadcast the new feed item to all connected clients
    PartnersWeb.Endpoint.broadcast("home_feed", "new_feed_item", %{
      username: "Anonymous",
      region_name: region_name,
      region_code_code: region_code,
      time_zone: time_zone,
      flag_url: ~p"/images/flags/#{@australian_regions[region_code][:flag]}",
      action: "Viewing Now"
    })

    maybe_send_admin_email(responseHeaders["ipregistry-credits-remaining"])

    {:noreply, socket}
  end

  # Handle the event when the API call doesn't need to be made - we only receive the stored data in localStorage
  @impl true
  def handle_event("ip_registry_data", %{"status" => "OK", "result" => result}, socket) do
    IO.inspect(result, label: "Response Data")

    region_name = result["location"]["region"]["name"]
    region_code = result["location"]["region"]["code"]
    time_zone = result["time_zone"]["abbreviation"]

    # Broadcast the new feed item to all connected clients
    PartnersWeb.Endpoint.broadcast("home_feed", "new_feed_item", %{
      username: "Anonymous",
      region_name: region_name,
      region_code_code: region_code,
      time_zone: time_zone,
      flag_url: ~p"/images/flags/#{@australian_regions[region_code][:flag]}",
      action: "Viewing Now"
    })

    {:noreply, socket}
  end

  # Handle the event when the API call is unsuccssful and error received
  def handle_event("ip_registry_data", %{"status" => "error", "result" => error}, socket) do
    # Handle the error case here
    IO.inspect(error)
    {:noreply, socket}
  end

  # Handle broadcasted event from the server
  # This is the event that is sent from the server when a new feed item is created
  @impl true
  def handle_info(
        %{
          topic: "home_feed",
          event: "new_feed_item",
          payload: payload
        },
        socket
      ) do
    socket =
      socket
      |> stream_insert(
        :feed,
        Map.merge(payload, %{
          id: :os.system_time(:seconds) |> Integer.to_string()
        }),
        at: 0
      )

    {:noreply, socket}
  end

  # Handle the tick event from the timer
  # This is the event that is sent from the server every 8 seconds
  # to generate a random feed item
  @impl true
  def handle_info(:tick, socket) do
    # Let's assign random feed data to the socket
    {region_code, %{name: region_name, flag: flag_svg_name, time_zone: time_zone}} =
      random_region()

    socket =
      socket
      |> stream_insert(
        :feed,
        %{
          username: "Anon",
          region_name: region_name,
          region_code_code: region_code,
          time_zone: time_zone,
          flag_url: ~p"/images/flags/#{flag_svg_name}",
          action: "Viewing",
          id: :os.system_time(:seconds) |> Integer.to_string()
        },
        at: 0
      )

    {:noreply, socket}
  end

  @impl true

  def terminate({:shutdown, reason}, socket) when reason in [:closed, :left] do
    # Unsubscribe from the topic when the socket is closed
    :timer.cancel(socket.assigns.timer_ref)
    {:stop, :normal, socket}
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

  defp random_region() do
    # Generate a random region code from the @flags map
    Enum.random(@australian_regions)
  end
end

# Example of the response data from the IP registry API
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
