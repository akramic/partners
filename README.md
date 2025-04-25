# Partners

LovingPartners is a social app designed for real time interactions using webrtc video calling and live chat.

## Reduced bots and fake accounts

Profile photos are taken on the app. Profile videos are also recorded on the app.
Users need to allow browser geolocation in order to get their true rather than stated location.
These features help to minimise the number of fake accounts which in turn reduces the risk of users of the app being taken in by unscrupulous actors.

### Set up changes for generators

1. Use binary ids.
2. Use :utc_datetime

### Platform and core dependencies

1. Phoenix ~> 1.8.0-rc.0
2. Live View ~> 1.0
3. Erlang OTP 27
4. Elixir 1.18.1
5. Tailwindcss 4.0.9
6. esbuild 0.17.11.

Please see mix.exs for updated dependencies.

### npm dependencies

1. rxjs

### External services

1. IPRegistry for IP data.

Dependencies, services and platform information is updated as external services are added to the app.

## STUN / TURN server https://eturnal.net/doc/

# See the configuration file in `{/etc/eturnal.yml}`. See the .env file in local development for login details.

# Hosted on virtual server Binary Lane https://www.binarylane.com.au/mpanel/manage/turn.loving.partners

# TLS

A certificate is generated and renewed automatically using the bash script at https://github.com/acmesh-official/acme.sh

- Use wget to install the script.
- The turn server is not a webserver so a standalone certificate is issued using the command
  `{acme.sh --issue -d turn.loving.partners --alpn --tlsport 5349 --debug}`

- Before this command can be issued, the port needs to be disabled with the command
  `{ sudo kill $(sudo lsof -t -i:5349) }`

Once the command is run a .acme.sh directory is created in the user home directory. This directory contains a turn.loving.partners_ecc directory.
The latter contains turn.loving.partners.key and turn.loving.partners.csr files - the former is the key and the latter is the actual certificate.
The paths to both key and certificate file need to be set in the eturnal.yml file located at `{/etc/eturnal.yml}`.

When all this is done. Reboot the virtual server and enable the eturnal service with `{sudo systemctl enable eturnal.service}`.

We should now be good to go to accept STUN and TURN requests.
