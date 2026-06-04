# Home Assistant ↔ Traccar (REST Command)

Home Assistant **REST Command**로 Traccar **OsmAnd HTTP 프로토콜**(포트 **5055**)에 위치·속도 등을 전송합니다.

## 환경 (플레이스홀더)

| 항목 | 예시 | 설명 |
|------|------|------|
| Traccar | `<TRACCAR_IP>` | Traccar 서버 LAN 주소 |
| HTTP 포트 | `5055` | OsmAnd 프로토콜 기본 포트 |
| 디바이스 ID | `<DEVICE_ID>` | Traccar에 등록한 **Unique ID** (`id` 파라미터) |

```
스마트폰 GPS (device_tracker) ──► HA 자동화 ──REST GET──► Traccar :5055
OBD (Colorado Tab5) ──속도·주행거리·activity──┘
```

Traccar 웹 UI에서 **장치 추가 → Identifier(Unique ID)** 가 REST Command의 `id`와 일치해야 합니다.

| 추가 플레이스홀더 | 예시 | 설명 |
|------------------|------|------|
| 스마트폰 tracker | `<DEVICE_TRACKER>` | HA `device_tracker` entity 접미사 |
| OBD | `<OBD_DEVICE>` | [espcomponents/colorado](https://github.com/eigger/espcomponents/tree/master/packages/display/colorado) (예: `esp_colorado_tab5`) |

## 1. configuration.yaml — rest_command

`<TRACCAR_IP>`를 실제 값으로 바꿉니다. 정의되지 않은 선택 파라미터는 URL에 포함되지 않습니다.

```yaml
rest_command:
  send_to_traccar:
    url: >-
      http://<TRACCAR_IP>:5055/?id={{ id }}
      {%- if lat is defined and lat not in [None, 'None', ''] %}&lat={{ lat }}{% endif -%}
      {%- if lon is defined and lon not in [None, 'None', ''] %}&lon={{ lon }}{% endif -%}
      {%- if timestamp is defined and timestamp not in [None, 'None', ''] %}&timestamp={{ timestamp }}{% endif -%}
      {%- if speed is defined and speed not in [None, 'None', ''] %}&speed={{ speed }}{% endif -%}
      {%- if altitude is defined and altitude not in [None, 'None', ''] %}&altitude={{ altitude }}{% endif -%}
      {%- if bearing is defined and bearing not in [None, 'None', ''] %}&bearing={{ bearing }}{% endif -%}
      {%- if hdop is defined and hdop not in [None, 'None', ''] %}&hdop={{ hdop }}{% endif -%}
      {%- if batt is defined and batt not in [None, 'None', ''] %}&batt={{ batt }}{% endif -%}
      {%- if activity is defined and activity not in [None, 'None', 'unknown', 'unavailable', ''] %}&activity={{ activity }}{% endif -%}
      {%- if odometer is defined and odometer not in [None, 'None', ''] %}&odometer={{ odometer }}{% endif -%}
    method: GET
```

## 2. 호출 예시

### 최소 (위치 + 시간)

```yaml
service: rest_command.send_to_traccar
data:
  id: "<DEVICE_ID>"
  lat: 37.5665
  lon: 126.9780
  timestamp: "{{ (now().timestamp() * 1000) | int }}"
```

### OBD·텔레메트리 포함

```yaml
service: rest_command.send_to_traccar
data:
  id: "<DEVICE_ID>"
  lat: "{{ state_attr('device_tracker.my_car', 'latitude') }}"
  lon: "{{ state_attr('device_tracker.my_car', 'longitude') }}"
  timestamp: "{{ (now().timestamp() * 1000) | int }}"
  speed: "{{ states('sensor.my_car_speed') | float(0) }}"
  odometer: "{{ states('sensor.<OBD_DEVICE>_odometer') | int(0) }}"
  batt: "{{ states('sensor.my_car_battery') | float(0) }}"
```

OBD 센서 예: [espcomponents/colorado](https://github.com/eigger/espcomponents/tree/master/packages/display/colorado)

## 3. REST Command 변수

| 변수 | 필수 | 설명 |
|------|------|------|
| `id` | ✓ | Traccar 장치 Unique ID |
| `lat` | | 위도 |
| `lon` | | 경도 |
| `timestamp` | | ISO 8601 UTC (`YYYY-MM-DDTHH:MM:SSZ`) 또는 epoch ms |
| `speed` | | 속도 (km/h 또는 kn — Traccar 단위 설정 따름) |
| `altitude` | | 고도 (m) |
| `bearing` | | 방향 (°) |
| `hdop` | | GPS 정확도 (HDOP) |
| `batt` | | 배터리 (%) |
| `activity` | | 활동 상태 (`unknown`·`unavailable`은 제외) |
| `odometer` | | 주행거리 (km) |

`None`, `'None'`, 빈 문자열은 URL에서 자동 제외됩니다.

## 4. 위치 업데이트 자동화

스마트폰 **Companion App** `device_tracker`가 바뀔 때마다 Traccar로 전송합니다. OBD 연동 여부에 따라 두 가지 패턴을 씁니다.

| 패턴 | 용도 |
|------|------|
| [§4.1 GPS + OBD](#41-gps--obd) | 차량 OBD 속도·주행거리·엔진 부하 보강 |
| [§4.2 GPS만](#42-gps만-obd-없음) | OBD 없는 단말 — GPS 속도만으로 activity 판별 |

장치·Traccar ID가 다르면 `<DEVICE_TRACKER>`·`<DEVICE_ID>`를 기기마다 바꿉니다.

### 4.1 GPS + OBD

**OBD 속도·엔진 부하**로 `activity`·`speed`·`odometer`를 보강합니다.

### 동작 요약

```
device_tracker 변경  ──►  latitude 있음?  ──►  send_to_traccar
                              │
                              ├─ activity: 엔진 ON → In Vehicle / 속도별 Still·Walking·Running
                              ├─ speed: OBD 우선, 없으면 GPS×3.6 (km/h)
                              └─ odometer: 엔진 ON일 때만 OBD 계기판
```

### entity (플레이스홀더)

| 용도 | entity_id |
|------|-----------|
| GPS 위치 | `device_tracker.<DEVICE_TRACKER>` |
| 배터리 | `sensor.<DEVICE_TRACKER>_battery_level` |
| OBD 속도 | `sensor.<OBD_DEVICE>_car_speed` |
| OBD 엔진 부하 | `sensor.<OBD_DEVICE>_engine_load` |
| OBD 주행거리 | `sensor.<OBD_DEVICE>_odometer` |

### 자동화 (YAML)

```yaml
alias: Traccar 위치 업데이트
description: 스마트폰 GPS와 OBD 텔레메트리를 Traccar에 전송합니다.
mode: queued
triggers:
  - trigger: state
    entity_id: device_tracker.<DEVICE_TRACKER>
conditions:
  - condition: template
    value_template: "{{ state_attr('device_tracker.<DEVICE_TRACKER>', 'latitude') != none }}"
actions:
  - action: rest_command.send_to_traccar
    data:
      id: "<DEVICE_ID>"
      lat: "{{ state_attr('device_tracker.<DEVICE_TRACKER>', 'latitude') | default('', true) }}"
      lon: "{{ state_attr('device_tracker.<DEVICE_TRACKER>', 'longitude') | default('', true) }}"
      timestamp: "{{ as_timestamp(now()) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ', false) }}"
      activity: |-
        {% if states('sensor.<OBD_DEVICE>_engine_load') | float(0) > 0 %}
          In Vehicle
        {% else %}
          {% set car_speed = states('sensor.<OBD_DEVICE>_car_speed') %}
          {% if car_speed not in ['unknown', 'unavailable', 'None', ''] %}
            {% set current_speed = car_speed | float(0) %}
          {% else %}
            {% set gps_speed = state_attr('device_tracker.<DEVICE_TRACKER>', 'speed') %}
            {% set current_speed = (gps_speed | float(0) * 3.6) if gps_speed not in [none, 'None', ''] else 0 %}
          {% endif %}
          {% if current_speed < 1.0 %}
            Still
          {% elif current_speed < 7.0 %}
            Walking
          {% elif current_speed < 15.0 %}
            Running
          {% else %}
            In Vehicle
          {% endif %}
        {% endif %}
      speed: >-
        {% set car_speed = states('sensor.<OBD_DEVICE>_car_speed') %}
        {% set gps_speed = state_attr('device_tracker.<DEVICE_TRACKER>', 'speed') %}
        {% set current_gps = (gps_speed | float(0) * 3.6) | round(1) if gps_speed not in [none, 'None', ''] else 0.0 %}
        {% if car_speed not in ['unknown', 'unavailable', 'None', ''] %}
          {{ car_speed | float(0) | round(1) }}
        {% else %}
          {{ current_gps }}
        {% endif %}
      odometer: |-
        {% if states('sensor.<OBD_DEVICE>_engine_load') | float(0) > 0 %}
          {{ states('sensor.<OBD_DEVICE>_odometer') | default('', true) }}
        {% else %}
          
        {% endif %}
      batt: "{{ states('sensor.<DEVICE_TRACKER>_battery_level') | default('', true) }}"
      altitude: "{{ state_attr('device_tracker.<DEVICE_TRACKER>', 'altitude') | default('', true) }}"
      bearing: "{{ state_attr('device_tracker.<DEVICE_TRACKER>', 'course') | default('', true) }}"
      hdop: "{{ state_attr('device_tracker.<DEVICE_TRACKER>', 'gps_accuracy') | default('', true) }}"
    response_variable: response
```

### activity·speed 판별

| 조건 | activity | speed |
|------|----------|-------|
| 엔진 부하 > 0 | `In Vehicle` | OBD `car_speed` 우선 |
| 속도 < 1 km/h | `Still` | OBD 또는 GPS×3.6 |
| 1–7 km/h | `Walking` | |
| 7–15 km/h | `Running` | |
| ≥ 15 km/h | `In Vehicle` | |

- GPS `speed` attr는 **m/s** → ×3.6으로 km/h 변환
- `odometer`는 **시동 ON**(엔진 부하 > 0)일 때만 전송 — 보행 중 OBD 값 혼입 방지
- `mode: queued` — 연속 위치 갱신 시 전송 누락 방지

### 4.2 GPS만 (OBD 없음)

OBD 센서 없이 **Companion GPS**만으로 위치·속도·activity를 전송합니다. Traccar 장치·`device_tracker`가 OBD 연동 단말과 **별도**일 때 사용합니다.

#### 동작 요약

```
device_tracker 변경  ──►  latitude 있음?  ──►  send_to_traccar
                              │
                              ├─ activity: GPS 속도(km/h)로 Still·Walking·Running·In Vehicle
                              └─ speed: GPS m/s × 3.6
```

#### entity (플레이스홀더)

| 용도 | entity_id |
|------|-----------|
| GPS 위치 | `device_tracker.<DEVICE_TRACKER>` |

#### 자동화 (YAML)

```yaml
alias: Traccar 위치 업데이트 (GPS만)
description: Companion GPS만으로 Traccar에 위치·속도를 전송합니다.
mode: queued
triggers:
  - trigger: state
    entity_id: device_tracker.<DEVICE_TRACKER>
conditions:
  - condition: template
    value_template: "{{ state_attr('device_tracker.<DEVICE_TRACKER>', 'latitude') != none }}"
actions:
  - action: rest_command.send_to_traccar
    data:
      id: "<DEVICE_ID>"
      lat: "{{ state_attr('device_tracker.<DEVICE_TRACKER>', 'latitude') | default('', true) }}"
      lon: "{{ state_attr('device_tracker.<DEVICE_TRACKER>', 'longitude') | default('', true) }}"
      timestamp: "{{ as_timestamp(now()) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ', false) }}"
      activity: |-
        {% set gps_speed = state_attr('device_tracker.<DEVICE_TRACKER>', 'speed') %}
        {% if gps_speed not in [none, 'None', '', 'unknown', 'unavailable'] %}
          {% set current_speed = (gps_speed | float(0) * 3.6) | round(1) %}
          {% if current_speed < 2.0 %}
            Still
          {% elif current_speed < 7.0 %}
            Walking
          {% elif current_speed < 20.0 %}
            Running
          {% else %}
            In Vehicle
          {% endif %}
        {% else %}
          Unknown
        {% endif %}
      speed: >-
        {% set gps_speed = state_attr('device_tracker.<DEVICE_TRACKER>', 'speed') %}
        {{ (gps_speed | float(0) * 3.6) | round(1) if gps_speed not in [none, 'None', ''] else '' }}
      altitude: "{{ state_attr('device_tracker.<DEVICE_TRACKER>', 'altitude') | default('', true) }}"
      bearing: "{{ state_attr('device_tracker.<DEVICE_TRACKER>', 'course') | default('', true) }}"
      hdop: "{{ state_attr('device_tracker.<DEVICE_TRACKER>', 'gps_accuracy') | default('', true) }}"
    response_variable: response
```

#### activity·speed 판별 (GPS만)

| 속도 (km/h) | activity |
|-------------|----------|
| GPS 없음 | `Unknown` |
| < 2 | `Still` |
| 2 – 7 | `Walking` |
| 7 – 20 | `Running` |
| ≥ 20 | `In Vehicle` |

- §4.1(OBD)과 **임계값이 다름** — GPS-only는 저속 구간을 넓게 잡음 (Still < 2 km/h)
- `odometer`·`batt` 미전송 — OBD·배터리 센서 없음

## 5. Traccar 측 확인

1. **설정 → 서버** — 포트 **5055** OsmAnd 프로토콜 활성화
2. **장치** — Identifier = HA에서 보내는 `id`
3. 전송 후 Traccar 지도·로그에서 포인트 수신 확인

## 6. 문제 해결

| 증상 | 조치 |
|------|------|
| 장치 offline | `id`가 Traccar Unique ID와 일치하는지 확인 |
| 위치 없음 | `lat`·`lon` 값·템플릿 오류 확인 |
| 시간 이상 | `timestamp` 형식 확인 (ISO UTC 또는 ms epoch) |
| 연결 실패 | `<TRACCAR_IP>:5055` 방화벽·Docker 포트 매핑 확인 |

## 7. 보안

- LAN 내부 또는 VPN 뒤에 두고 5055를 인터넷에 직접 노출하지 않음
- `id`만으로 위치 주입 가능 — Unique ID는 추측하기 어렵게 설정
