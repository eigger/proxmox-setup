# Cloudflared

**Language:** [한국어](README.md) · [English](README.en.md)

[Cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) — Cloudflare Tunnel client. Use to expose LAN services via Cloudflare without port forwarding.

## Installation

Proxmox VE **LXC** install script: [Cloudflared — Proxmox VE Helper Scripts](https://community-scripts.org/scripts/cloudflared)

1. Run the command below from the Proxmox host **Shell**
2. In the wizard, choose **Default** or **Advanced**, then create the LXC

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/cloudflared.sh)"
```

After install: check LAN IP on LXC **Summary** · config file `/usr/local/etc/cloudflared/config.yml`

## Tunnel setup

Create a tunnel in the Cloudflare Zero Trust dashboard, register the service on the LXC with a token, then connect internal services via Public Hostname.

| Topic | Document |
|-------|----------|
| Tunnel provisioning and subdomains | [tunnel-setup.en.md](tunnel-setup.en.md) |

## Home Assistant integration

When HA sits behind the tunnel, `trusted_proxies` configuration is required.

| packages (`/config/packages/`) | Description |
|--------------------------------|-------------|
| [http.yaml](../homeassistant/packages/http.yaml) | `use_x_forwarded_for`, `trusted_proxies` |

| Integration guide | Document |
|-------------------|----------|
| Tunnel + HA setup steps | [tunnel-setup.en.md](tunnel-setup.en.md#5-home-assistant--trusted_proxies) |
| HA packages and secrets layout | [homeassistant/config-structure.en.md](../homeassistant/config-structure.en.md) |

Official docs: [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)

## Folder layout

```
cloudflared/
├── README.md
├── README.en.md
├── tunnel-setup.md          # Tunnel setup, HA trusted_proxies
└── tunnel-setup.en.md
```

HA packages: [http.yaml](../homeassistant/packages/http.yaml)

## Secrets

Do **not** commit tunnel tokens, certificates, or API keys.
