/*

Service to get IP information from ipregistry.co and device details.
Provides a layer of security in respect of the user's IP address and device. See security section of response.


https://ipregistry.co/docs/endpoints#origin-ip

{
    "ip": "117.20.68.135",
    "type": "IPv4",
    "hostname": null,
    "carrier": {
        "name": null,
        "mcc": null,
        "mnc": null
    },
    "company": {
        "domain": "wideband.net.au",
        "name": "Aussie Broadband",
        "type": "isp"
    },
    "connection": {
        "asn": 4764,
        "domain": "wideband.net.au",
        "organization": "Wideband Networks Pty LTD",
        "route": "117.20.68.0/22",
        "type": "isp"
    },
    "currency": {
        "code": "AUD",
        "name": "Australian Dollar",
        "name_native": "Australian Dollar",
        "plural": "Australian dollars",
        "plural_native": "Australian dollars",
        "symbol": "A$",
        "symbol_native": "$",
        "format": {
            "decimal_separator": ".",
            "group_separator": ",",
            "negative": {
                "prefix": "-$",
                "suffix": ""
            },
            "positive": {
                "prefix": "$",
                "suffix": ""
            }
        }
    },
    "location": {
        "continent": {
            "code": "OC",
            "name": "Oceania"
        },
        "country": {
            "area": 7686850,
            "borders": [],
            "calling_code": "61",
            "capital": "Canberra",
            "code": "AU",
            "name": "Australia",
            "population": 26658948,
            "population_density": 3.47,
            "flag": {
                "emoji": "\uD83C\uDDE6\uD83C\uDDFA",
                "emoji_unicode": "U+1F1E6 U+1F1FA",
                "emojitwo": "https://cdn.ipregistry.co/flags/emojitwo/au.svg",
                "noto": "https://cdn.ipregistry.co/flags/noto/au.png",
                "twemoji": "https://cdn.ipregistry.co/flags/twemoji/au.svg",
                "wikimedia": "https://cdn.ipregistry.co/flags/wikimedia/au.svg"
            },
            "languages": [
                {
                    "code": "en",
                    "name": "English",
                    "native": "English"
                }
            ],
            "tld": ".au"
        },
        "region": {
            "code": "AU-QLD",
            "name": "Queensland"
        },
        "city": "Milton",
        "postal": "4064",
        "latitude": -27.47421,
        "longitude": 153.0038,
        "language": {
            "code": "en",
            "name": "English",
            "native": "English"
        },
        "in_eu": false
    },
    "security": {
        "is_abuser": false,
        "is_attacker": false,
        "is_bogon": false,
        "is_cloud_provider": false,
        "is_proxy": false,
        "is_relay": false,
        "is_tor": false,
        "is_tor_exit": false,
        "is_vpn": false,
        "is_anonymous": false,
        "is_threat": false
    },
    "time_zone": {
        "id": "Australia/Brisbane",
        "abbreviation": "AEST",
        "current_time": "2025-04-20T09:55:46+10:00",
        "name": "Australian Eastern Standard Time",
        "offset": 36000,
        "in_daylight_saving": false
    },
    "user_agent": {
        "header": "Mozilla/5.0 (X11; Linux x86_64; rv:137.0) Gecko/20100101 Firefox/137.0",
        "name": "Firefox",
        "type": "browser",
        "version": "137.0",
        "version_major": "137",
        "device": {
            "brand": null,
            "name": "Linux Desktop",
            "type": "desktop"
        },
        "engine": {
            "name": "Gecko",
            "type": "browser",
            "version": "137.0",
            "version_major": "137"
        },
        "os": {
            "name": "Linux",
            "type": "desktop",
            "version": null
        }
    }
}

*/



const base_url = "https://api.ipregistry.co/?key=";

// Create a partially applied function that returns a function requiring the api key for ipregistry api call
export const buildURL = (key) => `${base_url}${key}`
