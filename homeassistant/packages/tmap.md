# packages/tmap.yaml

**Language:** [한국어](tmap.md) · [English](tmap.en.md)

[SK open API — TMAP 자동차 경로안내](https://openapi.sk.com/products/detail?linkMenuSeq=46) (`/tmap/routes`)를 HA `rest_command`로 호출합니다.

HA 경로: `/config/packages/tmap.yaml`

## 사전 조건

1. [SK open API](https://openapi.sk.com/) 가입 후 **TMAP 경로안내** 상품 appKey 발급
2. `secrets.yaml`:

```yaml
tmap_api_key: "<TMAP_APP_KEY>"
```

## 서비스

| 서비스 | 용도 |
|--------|------|
| `rest_command.request_tmap_routes` | 출발·도착 좌표로 경로 검색 |

### 호출 예시

WGS84 경위도(또는 TMAP API 문서의 좌표계)를 `startX`/`startY`(경도·위도), `endX`/`endY`에 넣습니다.

```yaml
service: rest_command.request_tmap_routes
data:
  startX: 126.9780
  startY: 37.5665
  endX: 127.0276
  endY: 37.4979
  searchOption: 0
```

| data | 설명 |
|------|------|
| `startX`, `startY` | 출발 경도·위도 |
| `endX`, `endY` | 도착 경도·위도 |
| `searchOption` | 경로 옵션 (예: `0` 추천, `1` 최단, `2` 최소시간 등 — [API 문서](https://skopenapi.readme.io/reference/%EC%9E%90%EB%8F%99%EC%B0%A8-%EA%B2%BD%EB%A1%9C%EC%95%88%EB%82%B4) 참고) |

고정 payload: `totalValue: 2`, `trafficInfo: Y`, `mainRoadInfo: Y`.

응답은 GeoJSON `FeatureCollection` 형식입니다. 자동화에서 `rest_command` 결과를 파싱하거나, 별도 `sensor`/`template`으로 후처리합니다.

## 적용

1. `secrets.yaml`에 `tmap_api_key` 추가
2. `packages/tmap.yaml` 배치
3. **개발자 도구 → YAML** 구성 확인
