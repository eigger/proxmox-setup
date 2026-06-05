# grocy

**Language:** [한국어](README.md) · [English](README.en.md)

[grocy](https://grocy.info/) — self-hosted web app for grocery and household stock, shopping lists, recipes, and meal planning.

## Installation

Proxmox VE **LXC** install script: [grocy — Proxmox VE Helper Scripts](https://community-scripts.org/scripts/grocy)

1. Run the command below on the Proxmox host **Shell**
2. Choose **Default** or **Advanced** in the wizard to create the LXC

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/grocy.sh)"
```

Web UI after install: `http://<GROCY_IP>` (default port **80**)

### Initial setup

Default script credentials: `admin` / `admin` — **change the password on first login**

## Home Assistant integration

| Integration guide | Document |
|-------------|------|
| Niimbot labels (grocy Webhook → HA) | [ha-niimbot.en.md](ha-niimbot.en.md) |
| hass-niimbot example | [github.com/eigger/hass-niimbot/.../grocy](https://github.com/eigger/hass-niimbot/tree/master/examples/grocy) |
| HA packages · secrets layout | [homeassistant/config-structure.en.md](../homeassistant/config-structure.en.md) |

## Folder structure

```
grocy/
├── README.md
└── ha-niimbot.md            # HA integration details (Webhook automation)
```

No combined HA packages — Webhook automation is in [ha-niimbot.en.md](ha-niimbot.en.md) §2

## Secrets

Do **not** commit admin passwords, Webhook URLs, or API keys.
