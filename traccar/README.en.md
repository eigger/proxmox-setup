# Traccar

**Language:** [한국어](README.md) · [English](README.en.md)

[Traccar](https://www.traccar.org/) — GPS tracking server. Reference material for self-hosting on Proxmox VM/LXC or Docker and sending location/telemetry from Home Assistant and other clients.

## Installation

Proxmox VE **LXC** install script: [Traccar — Proxmox VE Helper Scripts](https://community-scripts.org/scripts/traccar)

1. Run the command below on the Proxmox host **Shell**
2. Choose **Default** or **Advanced** in the wizard to create the LXC

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/traccar.sh)"
```

Web UI after install: `http://<TRACCAR_IP>:8082` (default port **8082**)  
HA integration (OsmAnd HTTP): port **5055**

## Home Assistant integration

| packages (`/config/packages/`) | Description |
|----------------------------------|------|
| [traccar.yaml](../homeassistant/packages/traccar.yaml) | `send_to_traccar` REST Command |

| Integration guide | Document |
|-------------|------|
| REST Command · variables · call examples | [ha-rest-command.en.md](ha-rest-command.en.md) |
| GPS + OBD location automation | [ha-rest-command.en.md](ha-rest-command.en.md#41-gps--obd) |
| GPS-only location automation | [ha-rest-command.en.md](ha-rest-command.en.md#42-gps-only-no-obd) |
| HA packages · secrets layout | [homeassistant/config-structure.en.md](../homeassistant/config-structure.en.md) |

## Folder structure

```
traccar/
├── README.md
└── ha-rest-command.md       # HA integration details (automation · OBD)
```

HA packages: [traccar.yaml](../homeassistant/packages/traccar.yaml)

## Secrets

Store Traccar server address and device IDs in `secrets.yaml` as needed for your environment — do **not** commit them.
