# Cloudflare DDNS

**Language:** [한국어](README.md) · [English](README.en.md)

[favonia/cloudflare-ddns](https://github.com/favonia/cloudflare-ddns) — lightweight DDNS updater that refreshes Cloudflare DNS **A/AAAA** records when the public IP changes.

## Installation

Proxmox VE **LXC** install script: [Cloudflare-DDNS — Proxmox VE Helper Scripts](https://community-scripts.org/scripts/cloudflare-ddns)

1. Run the command below from the Proxmox host **Shell**
2. In the wizard, choose **Default** or **Advanced**, then create the LXC
3. During install, enter **API token, domain, Proxied, IPv6** — [ddns-setup.en.md](ddns-setup.en.md)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/cloudflare-ddns.sh)"
```

After install: check service with `systemctl status cloudflare-ddns`

## DDNS configuration

| Topic | Document |
|-------|----------|
| API token, domain, service edits | [ddns-setup.en.md](ddns-setup.en.md) |

Config file: `/etc/systemd/system/cloudflare-ddns.service`  
Upstream: [favonia/cloudflare-ddns](https://github.com/favonia/cloudflare-ddns)

## Folder layout

```
cloudflare-ddns/
├── README.md
├── README.en.md
├── ddns-setup.md            # Cloudflare API token, DDNS env vars
└── ddns-setup.en.md
```

## Secrets

Do **not** commit `CLOUDFLARE_API_TOKEN`.
