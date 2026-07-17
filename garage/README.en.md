# Garage

**Language:** [한국어](README.md) · [English](README.en.md)

[Garage](https://github.com/eigger/garage) — self-hosted family car management web app (maintenance schedules, fuel logs, reminders, OBD/GPS trips, and optional Home Assistant integrations).

## Installation

Proxmox VE **LXC** install script:

1. Run the command below on the Proxmox host **Shell**
2. Follow the wizard steps to create the LXC

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/eigger/garage/master/proxmox/ct/garage.sh)"
```

Web UI after installation: `http://<GARAGE_IP>` (default port **80**)

### Initial Setup

1. On first run, if the user table is empty, you will be redirected to the **Bootstrap Admin** page. Enter your name, email, and password to create the administrator account.
2. Go to the bottom navigation bar **More** → **Vehicle Management** and register your vehicle. Setting the fuel type automatically copies corresponding maintenance master presets and admin/legal schedules (insurance, tax, inspection).

## Home Assistant Integration

| packages (`/config/packages/`) | Description |
|----------------------------------|-------------|
| [garage.yaml](../homeassistant/packages/garage.yaml) | Garage telemetry REST Command and sensors definitions |

| Integration Guide | Document |
|-------------------|----------|
| HA packages·secrets layout | [homeassistant/config-structure.en.md](../homeassistant/config-structure.en.md) |

### 1. Telemetry Ingest (HA → Garage)
Send live location, speed, and odometer updates to the Garage server when driving. Use the `garage_send_telemetry` REST Command defined in `/config/packages/garage.yaml`.
* **Authentication**: Use the `apiToken` issued in vehicle settings (**Vehicle detail → OBD & GPS**) using either an Authorization Bearer header or the `?token=TOKEN` query parameter.
* **Endpoint URL**: `POST http://<GARAGE_IP>/api/ingest/telemetry`

### 2. Status & Reminders Read (Garage → HA)
Monitor vehicle sensor values and pending maintenance reminders using HA `rest` platform sensors.
* **Vehicle status API**: `GET http://<GARAGE_IP>/api/ingest/status?token=<VEHICLE_API_TOKEN>`
* **Reminders API**: `GET http://<GARAGE_IP>/api/ingest/reminders?token=<VEHICLE_API_TOKEN>`

## Folder Structure

```
garage/
└── README.en.md
```

HA packages: [garage.yaml](../homeassistant/packages/garage.yaml)

## Secrets

Store the Garage host address and API token in your `secrets.yaml` and **do not** commit them.
```yaml
garage_host: "http://<GARAGE_IP>"
garage_vehicle_token: "YOUR_VEHICLE_API_TOKEN"
```
