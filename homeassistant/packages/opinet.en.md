# packages/opinet.yaml

**Language:** [한국어](opinet.md) · [English](opinet.en.md)

Fetches Nanuri SK gasoline, diesel, and premium gasoline prices via the [Opinet](https://www.opinet.co.kr) **station detail API** as REST sensors. LubeLogger and grocy fuel scripts use `sensor.nanuri_sk_hwibalyu`, etc.

HA path: `/config/packages/opinet.yaml`

## Prerequisites

1. [Opinet API key issuance](../../lubelogger/ha-fuel-opinet.en.md#1-opinet-api-key)
2. `secrets.yaml`:

```yaml
opinet_nanuri_url: "https://www.opinet.co.kr/api/detailById.do?code=<API>&id=<주유소ID>&out=json"
```

## Created sensors

| name | entity_id (example) | Fuel type |
|------|----------------|------|
| 나누리 SK 휘발유 | `sensor.nanuri_sk_hwibalyu` | B027 |
| 나누리 SK 경유 | `sensor.nanuri_sk_gyeongyu` | D047 |
| 나누리 SK 고급휘발유 | `sensor.nanuri_sk_gogeubhwbalyu` | B034 |

- `scan_interval: 3600` — refresh every hour (saves API quota)
- On API failure, **keeps previous value** (`{% else %}` fallback)

## Integration

| Use | Doc |
|------|------|
| LubeLogger amount-based fueling | [lubelogger/ha-fuel-opinet.en.md](../../lubelogger/ha-fuel-opinet.en.md#4-amount-based-fuel-script) |
| Opinet setup details | [lubelogger/ha-fuel-opinet.en.md](../../lubelogger/ha-fuel-opinet.en.md) |

## Apply

1. Add `opinet_nanuri_url` to `secrets.yaml`
2. Deploy `packages/opinet.yaml`
3. **Developer tools → YAML** — check configuration
