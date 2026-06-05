# packages/traccar.yaml

[Traccar](https://www.traccar.org) **OsmAnd HTTP 프로토콜**(포트 **5055**)로 위치·속도·OBD 텔레메트리를 GET 전송합니다.

HA 경로: `/config/packages/traccar.yaml`

## 사전 조건

1. Traccar에 장치 등록 — **Unique ID**가 REST Command `id`와 일치
2. `traccar.yaml` URL의 `<TRACCAR_IP>`를 실제 LAN 주소로 수정

## 서비스

| 서비스 | 용도 |
|--------|------|
| `rest_command.send_to_traccar` | Traccar `:5055` 위치 업데이트 |

### 최소 호출

```yaml
service: rest_command.send_to_traccar
data:
  id: "<DEVICE_ID>"
  lat: 37.5665
  lon: 126.9780
  timestamp: "{{ (now().timestamp() * 1000) | int }}"
```

### 선택 파라미터

| 변수 | 설명 |
|------|------|
| `lat`, `lon` | 위·경도 |
| `timestamp` | epoch ms 또는 ISO 8601 UTC |
| `speed`, `altitude`, `bearing`, `hdop` | 속도·고도·방향·정확도 |
| `batt`, `activity`, `odometer` | 배터리·활동·주행거리 |

`None`, `'None'`, 빈 문자열은 URL에서 자동 제외됩니다. `activity`는 `unknown`·`unavailable`도 제외합니다.

## 연동

| 주제 | 문서 |
|------|------|
| REST Command·변수·자동화 (GPS+OBD / GPS만) | [traccar/ha-rest-command.md](../../traccar/ha-rest-command.md) |

## 적용

1. `packages/traccar.yaml` 배치 후 `<TRACCAR_IP>` 수정
2. **개발자 도구 → YAML** 구성 확인
3. Traccar 웹 UI에서 위치 수신 확인
