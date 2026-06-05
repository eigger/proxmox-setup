# packages/tmap.yaml

**Language:** [한국어](tmap.md) · [English](tmap.en.md)

Calls [SK open API — TMAP car route guidance](https://openapi.sk.com/products/detail?linkMenuSeq=46) (`/tmap/routes`) via HA `rest_command`.

HA path: `/config/packages/tmap.yaml`

## Prerequisites

1. Sign up at [SK open API](https://openapi.sk.com/) and issue an appKey for **TMAP route guidance**
2. `secrets.yaml`:

```yaml
tmap_api_key: "<TMAP_APP_KEY>"
```

## Services

| Service | Purpose |
|--------|------|
| `rest_command.request_tmap_routes` | Route search by start·end coordinates |

### Example call

Put WGS84 longitude/latitude (or the coordinate system in the TMAP API docs) in `startX`/`startY` (lon·lat) and `endX`/`endY`.

```yaml
service: rest_command.request_tmap_routes
data:
  startX: 126.9780
  startY: 37.5665
  endX: 127.0276
  endY: 37.4979
  searchOption: 0
```

| data | Description |
|------|------|
| `startX`, `startY` | Start longitude·latitude |
| `endX`, `endY` | End longitude·latitude |
| `searchOption` | Route option (e.g. `0` recommended, `1` shortest, `2` minimum time — see [API docs](https://skopenapi.readme.io/reference/%EC%9E%90%EB%8F%99%EC%B0%A8-%EA%B2%BD%EB%A1%9C%EC%95%88%EB%82%B4)) |

Fixed payload: `totalValue: 2`, `trafficInfo: Y`, `mainRoadInfo: Y`.

Response is GeoJSON `FeatureCollection` format. Parse `rest_command` results in automations or post-process with a separate `sensor`/`template`.

## Apply

1. Add `tmap_api_key` to `secrets.yaml`
2. Deploy `packages/tmap.yaml`
3. **Developer tools → YAML** — check configuration
