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
`{sudo apt install extrepo
sudo extrepo enable eturnal
sudo apt update
sudo apt install eturnal}`


# See the configuration file in `{/etc/eturnal.yml}`. See the .env file in local development for login details.

# Hosted on virtual server Binary Lane https://www.binarylane.com.au/mpanel/manage/turn.loving.partners

# TLS

A certificate is generated and renewed automatically using the bash script at https://github.com/acmesh-official/acme.sh

- Use wget to install the script.
- The turn server is not a webserver so a standalone certificate is issued using the command
  `{acme.sh --issue -d turn.loving.partners --alpn --tlsport 5349 --debug}`
  `{acme.sh  --issue  -d turn.loving.partners  --standalone}`

- Before this command can be issued, the port needs to be disabled with the command
  `{ sudo kill $(sudo lsof -t -i:5349) }`

Once the command is run a .acme.sh directory is created in the user home directory. This directory contains a turn.loving.partners_ecc directory.
The latter contains turn.loving.partners.key and turn.loving.partners.csr files - the former is the key and the latter is the actual certificate.
The paths to both key and certificate file need to be set in the eturnal.yml file located at `{/etc/eturnal.yml}`.

When all this is done. Reboot the virtual server and enable the eturnal service with `{sudo systemctl enable eturnal.service}`.

We should now be good to go to accept STUN and TURN requests.


## Hosting & Infrastructure

### Architecture Overview
- **Application + Database**: Fly.io (Sydney region)
- **Video Content**: Bunny CDN (30-second profile videos)
- **Preview Animations**: WebP animations via Bunny CDN
- **TURN Server**: Binary Lane VPS (no egress/ingress fees)

### TURN Server Requirements
For an estimated 10,000 users:

| Resource | Minimum | Recommended | Explanation |
|----------|---------|-------------|-------------|
| CPU | 2 vCPUs | 4 vCPUs | Erlang efficiently uses multiple cores; 4 cores provide headroom for peak loads |
| RAM | 4GB | 8GB | Provides buffer for concurrent sessions and prevents OOM issues |
| Network | 100 Mbps | 250 Mbps | Handles peak traffic with margin for usage spikes |
| Storage | 20GB SSD | 40GB SSD | Mainly for OS, logs, and possible recording features |

With a 30% TURN relay requirement, this configuration supports approximately:
- 2,000 daily active users
- 100-200 concurrent video calls
- 30-60 calls relayed through TURN
- ~96 Mbps peak bandwidth

### Budget Estimate (10,000 Users)

| Service | Lower Estimate | Higher Estimate | Notes |
|---------|----------------|----------------|-------|
| Fly.io Application | $20/month | $25/month | 2 VMs with 1GB RAM, shared CPU |
| Fly.io PostgreSQL | $60/month | $70/month | 1 CPU, 4GB RAM with PostGIS |
| Bunny CDN Storage | $0.21/month | $0.51/month | 20-50GB for videos, 0.5-1GB for WebP previews |
| Bunny CDN Video Bandwidth | $4/month | $15/month | 400GB-1.5TB/month @ $0.01/GB |
| Bunny CDN Preview Bandwidth | $0.50/month | $2/month | 50-200GB/month @ $0.01/GB |
| TURN Server (Binary Lane) | $20/month | $40/month | 4 vCPUs, 8GB RAM recommended |
| **TOTAL** | **$104.71/month** | **$152.51/month** | **$0.01-$0.015 per user per month** |

This translates to approximately 12-18 cents per user per year, with subscription revenue at $19 AUD per month providing significant margin for growth and additional features.


## Financial Projections

### Revenue Projections (at $19 AUD/month)

| Scenario | Monthly Revenue | Annual Revenue |
|----------|----------------|----------------|
| Conservative (800 subscribers) | $15,200 AUD | $182,400 AUD |
| Moderate (3,000 subscribers) | $57,000 AUD | $684,000 AUD |
| Optimistic (9,000 subscribers) | $171,000 AUD | $2,052,000 AUD |

### Operating Expenses (Self-Managed Business)

| Expense Category | Monthly Cost (AUD) | Annual Cost (AUD) | Notes |
|------------------|-------------------|-------------------|-------|
| Infrastructure | $105-$153 | $1,260-$1,836 | As detailed above |
| Initial Marketing | $167-$250 | $2,000-$3,000 | One-time cost at launch |
| Ongoing Marketing | $0 | $0 | Social media sharing only |
| Development & Maintenance | $0 | $0 | Self-developed and maintained |
| Customer Support | $0 | $0 | Handled by family business |
| Legal & Compliance | $100-$300 | $1,200-$3,600 | Minimal legal requirements |
| Accounting | $100-$200 | $1,200-$2,400 | Basic accounting services |
| Miscellaneous | $100 | $1,200 | Contingency |
| **Total Expenses** | **$472-$1,003** | **$5,660-$12,036** | |

### Profitability Analysis

| Scenario | Annual Revenue | Annual Expenses | Annual Profit | Profit Margin |
|----------|----------------|----------------|--------------|--------------|
| Conservative | $182,400 | $12,036 | $170,364 | 93% |
| Moderate | $684,000 | $12,036 | $671,964 | 98% |
| Optimistic | $2,052,000 | $12,036 | $2,039,964 | 99% |

### Key Financial Insights

- **Breakeven Point**: ~53 paying subscribers (0.53% conversion of 10,000 users)
- **Customer Acquisition Cost**: Minimal due to social media sharing strategy
- **Lifetime Value**: Estimated $159.60 AUD per subscriber (8.4 months average subscription)

The self-managed approach dramatically improves profitability by eliminating development and support costs. Even in the conservative scenario, profit margins exceed 90%. With Elixir's reliability reducing maintenance needs and the family-operated support model, the app can scale efficiently without proportional cost increases.

Using Fly.io, Bunny CDN, and Binary Lane creates an ideal technical infrastructure for an Australian-focused dating platform, with costs remaining sustainable even as the user base grows.