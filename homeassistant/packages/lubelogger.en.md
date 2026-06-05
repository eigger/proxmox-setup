# packages/lubelogger.yaml

**Language:** [한국어](lubelogger.md) · [English](lubelogger.en.md)

`rest_command` to POST **odometer and fuel records** to the [LubeLogger](https://lubelogger.com) API.

HA path: `/config/packages/lubelogger.yaml`

## Prerequisites

1. LubeLogger **Settings → Enable Authentication** (Basic Auth)
2. `secrets.yaml`:

```yaml
lubelogger_username: "<LUBELOGGER_USER>"
lubelogger_password: "<LUBELOGGER_PASSWORD>"
```

3. In `lubelogger.yaml`, set `<LUBELOGGER_IP>` and port (`5000`, etc.) to actual values

## Services

| Service | Purpose |
|--------|------|
| `rest_command.lubelogger_add_odometer` | Odometer record |
| `rest_command.lubelogger_add_fuel` | Fuel record |

### Odometer

```yaml
service: rest_command.lubelogger_add_odometer
data:
  vehicle_id: 1
  odometer: 16800
  notes: "오늘 날짜로 자동 기록됨"
```

`initial_odometer` is optional (initial odometer correction).

### Fuel

```yaml
service: rest_command.lubelogger_add_fuel
data:
  vehicle_id: 1
  odometer: 16580
  fuel_consumed: 45.5
  cost: 72000
  is_full: true
```

Omitting `is_full` defaults to `false`. For Opinet prices and amount-based scripts, see [ha-fuel-opinet.en.md](../../lubelogger/ha-fuel-opinet.en.md).

## Integration

| Topic | Doc |
|------|------|
| REST command details·OBD automations | [lubelogger/ha-rest-command.en.md](../../lubelogger/ha-rest-command.en.md) |
| Opinet price sensors | [opinet.yaml](opinet.yaml) · [ha-fuel-opinet.en.md](../../lubelogger/ha-fuel-opinet.en.md) |

## Apply

1. Add credentials to `secrets.yaml`
2. Deploy `packages/lubelogger.yaml` and set `<LUBELOGGER_IP>`
3. **Developer tools → YAML** — check configuration
