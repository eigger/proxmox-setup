# Home Assistant OS

**Language:** [한국어](README.md) · [English](README.en.md)

[Home Assistant OS](https://www.home-assistant.io/installation/linux) — runs HA OS on a Proxmox **VM**. Configuration is split by feature under **`packages/`**.

## Installation

Proxmox VE **VM** install script: [Home Assistant OS — Proxmox VE Helper Scripts](https://community-scripts.org/scripts/haos-vm)

Downloads the official HA Team **qcow2** image and creates the VM.

1. Run the command below in the Proxmox host **Shell**
2. Follow the wizard to choose storage, VM ID, etc.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/vm/haos-vm.sh)"
```

### After installation

- In Proxmox, check the **VM IP** on the **VM → Summary** (or Console) tab
- Web UI: `http://<HA_IP>:8123` (default port **8123**)
- Initial onboarding: create account, set region, add integrations

### Notes (script default profile)

| Item | Default |
|------|--------|
| vCPU | 2 |
| RAM | 4096 MB |
| Disk | **32 GB** (minimum 32 GB at creation; size cannot be changed) |

Official docs: [home-assistant.io](https://www.home-assistant.io/docs/)

## Configuration structure

`configuration.yaml` only loads packages; everything else lives in `packages/` as separate files.

```yaml
homeassistant:
  packages: !include_dir_named packages
```

Documentation hierarchy (LXC README → `ha-*.md` → packages YAML): [config-structure.en.md](config-structure.en.md)

### packages list

Full table and integration links: [packages/README.en.md](packages/README.en.md)

| packages | Integration details |
|----------|-----------|
| [http.yaml](packages/http.yaml) | [cloudflared/tunnel-setup.en.md](../cloudflared/tunnel-setup.en.md#5-home-assistant--trusted_proxies) |
| [hass-opinet](https://github.com/eigger/hass-opinet) | [lubelogger/ha-fuel-opinet.en.md](../lubelogger/ha-fuel-opinet.en.md) |
| [lubelogger.yaml](packages/lubelogger.yaml) | [lubelogger/ha-rest-command.en.md](../lubelogger/ha-rest-command.en.md) |
| [traccar.yaml](packages/traccar.yaml) | [traccar/ha-rest-command.en.md](../traccar/ha-rest-command.en.md) |
| [tasmota.yaml](packages/tasmota.yaml) | [tasmota.en.md](packages/tasmota.en.md) |
| [tmap.yaml](packages/tmap.yaml) | [tmap.en.md](packages/tmap.en.md) |
| [wol.yaml](packages/wol.yaml) | [wol.en.md](packages/wol.en.md) |
| [recorder.yaml](packages/recorder.yaml) | [recorder.en.md](packages/recorder.en.md) |

HA-only (no LXC folder): `tasmota`, `tmap`, `wol`, `recorder` — see packages and `*.en.md` only.

## LXC/VM services ↔ HA

Each service **README** covers installation and ports only; HA integration uses the packages above plus the `ha-*.md` files below.

| Service | LXC README | packages | Integration details |
|--------|------------|----------|-----------|
| LubeLogger | [lubelogger/README.en.md](../lubelogger/README.en.md) | lubelogger, [hass-opinet](https://github.com/eigger/hass-opinet) | [ha-rest-command.en.md](../lubelogger/ha-rest-command.en.md), [ha-fuel-opinet.en.md](../lubelogger/ha-fuel-opinet.en.md) |
| Traccar | [traccar/README.en.md](../traccar/README.en.md) | traccar | [ha-rest-command.en.md](../traccar/ha-rest-command.en.md) |
| grocy | [grocy/README.en.md](../grocy/README.en.md) | — | [ha-niimbot.en.md](../grocy/ha-niimbot.en.md) |
| Cloudflared | [cloudflared/README.en.md](../cloudflared/README.en.md) | http | [tunnel-setup.en.md](../cloudflared/tunnel-setup.en.md) |
| FreePBX | [freepbx/README.en.md](../freepbx/README.en.md) | — | [ha-hass-sip.en.md](../freepbx/ha-hass-sip.en.md) (Main), [ha-sip.en.md](../freepbx/ha-sip.en.md), [ha-asterisk.en.md](../freepbx/ha-asterisk.en.md) |

## Folder structure

```
homeassistant/
├── README.md
├── config-structure.md      # configuration.yaml + packages overview
└── packages/                # *.yaml + *.md — list in packages/README.en.md
```

## Secrets

Do **not** commit `secrets.yaml`, API keys, or tokens.
