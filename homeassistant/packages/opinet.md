# packages/opinet.yaml

**Language:** [한국어](opinet.md) · [English](opinet.en.md)

[오피넷](https://www.opinet.co.kr) **주유소 상세 API**로 나누리 SK 휘발유·경유·고급휘발유 단가를 REST 센서로 가져옵니다. LubeLogger·grocy 주유 스크립트에서 `sensor.nanuri_sk_hwibalyu` 등을 사용합니다.

HA 경로: `/config/packages/opinet.yaml`

## 사전 조건

1. [오피넷 API 키 발급](../../lubelogger/ha-fuel-opinet.md#1-오피넷-api-키-발급)
2. `secrets.yaml`:

```yaml
opinet_nanuri_url: "https://www.opinet.co.kr/api/detailById.do?code=<API>&id=<주유소ID>&out=json"
```

## 생성 센서

| name | entity_id (예) | 유종 |
|------|----------------|------|
| 나누리 SK 휘발유 | `sensor.nanuri_sk_hwibalyu` | B027 |
| 나누리 SK 경유 | `sensor.nanuri_sk_gyeongyu` | D047 |
| 나누리 SK 고급휘발유 | `sensor.nanuri_sk_gogeubhwbalyu` | B034 |

- `scan_interval: 3600` — 1시간마다 갱신 (API 호출 한도 절약)
- API 실패 시 **이전 값 유지** (`{% else %}` fallback)

## 연동

| 용도 | 문서 |
|------|------|
| LubeLogger 금액 기반 주유 | [lubelogger/ha-fuel-opinet.md](../../lubelogger/ha-fuel-opinet.md#4-금액-기반-주유-스크립트) |
| 오피넷 설정 상세 | [lubelogger/ha-fuel-opinet.md](../../lubelogger/ha-fuel-opinet.md) |

## 적용

1. `secrets.yaml`에 `opinet_nanuri_url` 추가
2. `packages/opinet.yaml` 배치
3. **개발자 도구 → YAML** 구성 확인
