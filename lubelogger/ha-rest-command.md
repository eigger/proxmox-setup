# Home Assistant ↔ LubeLogger (REST Command)

Home Assistant **REST Command**로 LubeLogger API에 주행거리·주유 기록을 추가합니다.

LXC 설치·포트: [README.md](README.md) · packages YAML: [lubelogger.yaml](../homeassistant/packages/lubelogger.yaml)

## 환경 (플레이스홀더)

| 항목 | 예시 | 설명 |
|------|------|------|
| LubeLogger | `<LUBELOGGER_IP>` | LubeLogger LAN 주소 |
| 포트 | `5000` | 인스턴스마다 다를 수 있음 (Docker 기본은 `8080` 등) |
| 차량 ID | `1` | LubeLogger UI에서 확인 (`vehicleId`) |
| OBD (ESPHome) | [espcomponents/colorado](https://github.com/eigger/espcomponents/tree/master/packages/display/colorado) | Tab5 + vLinker BLE → HA 센서 |

```
Home Assistant ──HTTP POST──► LubeLogger API
vLinker OBD2 ──BLE──► ESPHome (Colorado Tab5) ──MQTT──► Home Assistant
```

## 1. 사전 조건

1. LubeLogger **Settings → Enable Authentication** (Basic Auth)
2. `secrets.yaml`에 `lubelogger_username`, `lubelogger_password` 추가 — [lubelogger.md](../homeassistant/packages/lubelogger.md)

## 2. packages — rest_command

HA **packages** 패키지 파일 사용. 배치 후 URL의 `<LUBELOGGER_IP>`·포트를 실제 값으로 바꿉니다.

→ [homeassistant/packages/lubelogger.yaml](../homeassistant/packages/lubelogger.yaml) · [lubelogger.md](../homeassistant/packages/lubelogger.md)

### 헤더

| 헤더 | 값 | 설명 |
|------|-----|------|
| `culture-invariant` | `true` | 숫자·날짜를 불변 문화권 형식으로 처리 (API 권장) |

## 3. 호출 예시

### 주행거리 기록

```yaml
service: rest_command.lubelogger_add_odometer
data:
  odometer: 45230
  notes: "월말 동기화"
```

초기 주행거리 포함:

```yaml
service: rest_command.lubelogger_add_odometer
data:
  odometer: 45230
  initial_odometer: 10000
```

### 주유 기록

[LubeLogger REST Command](ha-rest-command.md#2-packages--rest_command)와 오피넷 단가 조회는 [ha-fuel-opinet.md](ha-fuel-opinet.md)를 따릅니다. 오피넷 **API 키 발급**부터 진행하세요.

```yaml
service: rest_command.lubelogger_add_fuel
data:
  odometer: 45230
  fuel_consumed: 42.5
  cost: 85000
  is_full: true
  notes: "주유소 A"
```

## 4. OBD 연동 — 시동 OFF 시 주행거리 등록

OBD 센서는 ESPHome **Colorado Tab5** 대시보드([eigger/espcomponents — colorado](https://github.com/eigger/espcomponents/tree/master/packages/display/colorado))에서 수집합니다. M5Stack Tab5 + vLinker BLE OBD2 + `ble_elm327` 컴포넌트로 RPM, 연료, 주행거리 등을 HA에 노출하고, **엔진 부하가 0% 근처로 떨어지면**(시동 OFF) 해당 주행 구간을 LubeLogger에 기록합니다.

```
vLinker OBD2 ──BLE──► ESP32 Tab5 (ESPHome) ──MQTT──► Home Assistant ──REST──► LubeLogger
```

### ESPHome (OBD 센서 출처)

Colorado 패키지 README의 [Configuration Usage](https://github.com/eigger/espcomponents/tree/master/packages/display/colorado#configuration-usage)와 [ble_elm327 Setup](https://github.com/eigger/espcomponents/tree/master/packages/display/colorado#ble_elm327-setup-vlinker-obd2)을 따릅니다.

```yaml
substitutions:
  name: "esp-colorado-tab5"          # → HA entity_id 접두사: esp_colorado_tab5
  mac_vlinker: "<VLINKER_MAC>"

packages:
  remote:
    refresh: always
    url: https://github.com/eigger/espcomponents/
    files:
      - packages/display/colorado/colorado-tab5.yaml
```

OBD 센서만 별도 보드에 쓸 경우 `colorado-ble-elm327.yaml`만 포함해도 됩니다. upstream에도 [LubeLogger Odometer Auto-Sync](https://github.com/eigger/espcomponents/tree/master/packages/display/colorado#lubelogger-odometer-auto-sync) 예시가 있으며, 이 문서는 REST Command·메모 필드를 보강한 버전입니다.

### OBD 센서 (HA entity_id)

ESPHome `substitutions.name`의 하이픈(`-`)이 HA entity_id에서는 밑줄(`_`)로 바뀝니다.

| substitutions.name | HA 접두사 | 예시 entity_id |
|--------------------|-----------|----------------|
| `esp-colorado-tab5` | `esp_colorado_tab5` | `sensor.esp_colorado_tab5_engine_load` |

다른 보드·이름을 쓰면 `<OBD_DEVICE>`를 해당 접두사로 바꿉니다.

| 용도 | entity_id |
|------|-----------|
| 엔진 부하 (%) | `sensor.<OBD_DEVICE>_engine_load` |
| 트립 주행거리 | `sensor.<OBD_DEVICE>_trip_distance` |
| 계기판 주행거리 | `sensor.<OBD_DEVICE>_odometer` |
| 연료 잔량 (%) | `sensor.<OBD_DEVICE>_fuel_level` |
| 연료 잔량 (L, GM) | `sensor.<OBD_DEVICE>_fuel_level_liters` |
| 엔진 가동 시간 (초) | `sensor.<OBD_DEVICE>_engine_run_time` |

### 동작 요약

```
엔진 부하 < 1%  ──►  트립 거리 > 0.1  ──►  LubeLogger 주행거리 기록
                         │
                         ├─ odometer: 현재 계기판 값
                         ├─ initialOdometer: 출발 시점 (현재 − 트립)
                         └─ notes: 연료·운행시간
```

### 자동화 (YAML)

```yaml
alias: 주행거리 등록
description: 엔진 부하가 0으로 떨어지면 주행 기록을 LubeLogger로 전송합니다.
mode: single
triggers:
  - trigger: numeric_state
    entity_id: sensor.<OBD_DEVICE>_engine_load
    below: 1
conditions:
  - condition: numeric_state
    entity_id: sensor.<OBD_DEVICE>_trip_distance
    above: 0.1
actions:
  - variables:
      current_odo: "{{ states('sensor.<OBD_DEVICE>_odometer') | float(0) | int(0) }}"
      current_trip: "{{ states('sensor.<OBD_DEVICE>_trip_distance') | float(0) }}"
      current_fuel: "{{ states('sensor.<OBD_DEVICE>_fuel_level') | float(0) }}"
      init_odo: "{{ (current_odo - current_trip) | int(0) }}"
      fuel_liters: "{{ states('sensor.<OBD_DEVICE>_fuel_level_liters') | float(0) | round(1) }}"
      run_time_seconds: "{{ states('sensor.<OBD_DEVICE>_engine_run_time') | int(0) }}"
      formatted_time: "{{ run_time_seconds | int(0) | timestamp_custom('%H:%M:%S', false) }}"
  - action: rest_command.lubelogger_add_odometer
    data:
      vehicle_id: 1
      odometer: "{{ current_odo }}"
      initial_odometer: "{{ init_odo }}"
      notes: >-
        연료: {{ current_fuel | round(1) }}% ({{ fuel_liters }}L), 운행시간: {{ formatted_time }}
    response_variable: api_response
```

| 항목 | 설명 |
|------|------|
| `mode: single` | 이전 실행이 끝나기 전 재트리거 방지 |
| `initial_odometer` | `현재 주행거리 − 트립 거리` → 출발 시점 계기판 |
| `above: 0.1` | 짧은 정차·노이즈 무시 (단위는 OBD 센서 설정 따름) |
| `response_variable` | (선택) 개발자 도구에서 API 응답 확인용 |

## 5. REST Command 변수

### lubelogger_add_odometer

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `vehicle_id` | `1` | 차량 ID |
| `date` | 오늘 | `YYYY-MM-DD` |
| `odometer` | `0` | 주행거리 (km 또는 mi, LubeLogger 단위 설정 따름) |
| `notes` | `홈어시스턴트 자동 동기화` | 메모 |
| `initial_odometer` | (없음) | 선택. 초기 주행거리 |

### lubelogger_add_fuel

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `vehicle_id` | `1` | 차량 ID |
| `date` | 오늘 | `YYYY-MM-DD` |
| `odometer` | `0` | 주유 시점 주행거리 |
| `fuel_consumed` | `0.0` | 주유량 (L 또는 gal) |
| `cost` | `0` | 비용 |
| `is_full` | `false` | 가득 주유 여부 |
| `notes` | `홈어시스턴트 자동 동기화` | 메모 |

## 6. 문제 해결

| 증상 | 조치 |
|------|------|
| 401 Unauthorized | `secrets.yaml` 계정·비밀번호, LubeLogger 인증 활성화 여부 확인 |
| 연결 실패 | `<LUBELOGGER_IP>`·포트, HA ↔ LubeLogger LAN 통신 확인 |
| 숫자 형식 오류 | `culture-invariant: "true"` 헤더 유지 |
| 잘못된 차량 | `vehicle_id`를 LubeLogger UI의 차량 ID와 일치시킴 |

## 7. 보안

- 사용자명·비밀번호는 `secrets.yaml`에만 두고 **git에 커밋하지 않음**
- LubeLogger를 인터넷에 직접 노출하지 않음 (LAN 내부 또는 VPN)
