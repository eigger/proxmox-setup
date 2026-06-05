# packages/traccar.yaml

**Language:** [한국어](traccar.md) · [English](traccar.en.md)

Sends location, speed, and OBD telemetry to [Traccar](https://www.traccar.org) via the **OsmAnd HTTP protocol** (port **5055**) as GET requests.

HA path: `/config/packages/traccar.yaml`

## Prerequisites

1. Register device in Traccar — **Unique ID** must match REST command `id`
2. Set `<TRACCAR_IP>` in `traccar.yaml` to the actual LAN address

## Services

| Service | Purpose |
|--------|------|
| `rest_command.send_to_traccar` | Traccar `:5055` location update |

### Minimal call

```yaml
service: rest_command.send_to_traccar
data:
  id: "<DEVICE_ID>"
  lat: 37.5665
  lon: 126.9780
  timestamp: "{{ (now().timestamp() * 1000) | int }}"
```

### Optional parameters

| Variable | Description |
|------|------|
| `lat`, `lon` | Latitude·longitude |
| `timestamp` | epoch ms or ISO 8601 UTC |
| `speed`, `altitude`, `bearing`, `hdop` | Speed·altitude·bearing·accuracy |
| `batt`, `activity`, `odometer` | Battery·activity·odometer |

`None`, `'None'`, and empty strings are automatically omitted from the URL. `activity` also excludes `unknown` and `unavailable`.

## Integration

| Topic | Doc |
|------|------|
| REST command·variables·automations (GPS+OBD / GPS only) | [traccar/ha-rest-command.en.md](../../traccar/ha-rest-command.en.md) |

## Apply

1. Deploy `packages/traccar.yaml` and set `<TRACCAR_IP>`
2. **Developer tools → YAML** — check configuration
3. Verify location reception in Traccar web UI
