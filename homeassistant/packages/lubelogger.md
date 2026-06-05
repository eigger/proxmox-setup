# packages/lubelogger.yaml

**Language:** [한국어](lubelogger.md) · [English](lubelogger.en.md)

[LubeLogger](https://lubelogger.com) API에 **주행거리·주유 기록**을 POST하는 `rest_command`입니다.

HA 경로: `/config/packages/lubelogger.yaml`

## 사전 조건

1. LubeLogger **Settings → Enable Authentication** (Basic Auth)
2. `secrets.yaml`:

```yaml
lubelogger_username: "<LUBELOGGER_USER>"
lubelogger_password: "<LUBELOGGER_PASSWORD>"
```

3. `lubelogger.yaml` URL의 `<LUBELOGGER_IP>`·포트(`5000` 등)를 실제 값으로 수정

## 서비스

| 서비스 | 용도 |
|--------|------|
| `rest_command.lubelogger_add_odometer` | 주행거리 기록 |
| `rest_command.lubelogger_add_fuel` | 주유 기록 |

### 주행거리

```yaml
service: rest_command.lubelogger_add_odometer
data:
  vehicle_id: 1
  odometer: 16800
  notes: "오늘 날짜로 자동 기록됨"
```

`initial_odometer`는 선택 (초기 주행거리 보정).

### 주유

```yaml
service: rest_command.lubelogger_add_fuel
data:
  vehicle_id: 1
  odometer: 16580
  fuel_consumed: 45.5
  cost: 72000
  is_full: true
```

`is_full` 생략 시 `false`. 오피넷 단가·금액 기반 스크립트는 [ha-fuel-opinet.md](../../lubelogger/ha-fuel-opinet.md) 참고.

## 연동

| 주제 | 문서 |
|------|------|
| REST Command 상세·OBD 자동화 | [lubelogger/ha-rest-command.md](../../lubelogger/ha-rest-command.md) |
| 오피넷 단가 센서 | [opinet.yaml](opinet.yaml) · [ha-fuel-opinet.md](../../lubelogger/ha-fuel-opinet.md) |

## 적용

1. `secrets.yaml`에 계정 추가
2. `packages/lubelogger.yaml` 배치 후 `<LUBELOGGER_IP>` 수정
3. **개발자 도구 → YAML** 구성 확인
