# Home Assistant ↔ Traccar (REST Command)

**Language:** [한국어](ha-rest-command.md) · [English](ha-rest-command.en.md)

Send location, speed, and other data to Traccar **OsmAnd HTTP protocol** (port **5055**) via Home Assistant **REST Command**.

LXC install · port: [README.en.md](README.en.md) · packages YAML: [traccar.yaml](../homeassistant/packages/traccar.yaml)

## Environment (placeholders)

| Item | Example | Description |
|------|------|------|
| Traccar | `<TRACCAR_IP>` | Traccar server LAN address |
| HTTP port | `5055` | OsmAnd protocol default port |
| Device ID | `<DEVICE_ID>` | **Unique ID** registered in Traccar (`id` parameter) |

```
Smartphone GPS (device_tracker) ──► HA automation ──REST GET──► Traccar :5055
OBD (Colorado Tab5) ──speed · odometer · activity──┘
```

In Traccar web UI, **Add device → Identifier (Unique ID)** must match REST Command `id`.

| Additional placeholder | Example | Description |
|------------------|------|------|
| Smartphone tracker | `<DEVICE_TRACKER>` | HA `device_tracker` entity suffix |
| OBD | `<OBD_DEVICE>` | [espcomponents/colorado](https://github.com/eigger/espcomponents/tree/master/packages/display/colorado) (e.g. `esp_colorado_tab5`) |

## 1. packages — rest_command

Use HA **packages**. After placing the file, replace `<TRACCAR_IP>` in the URL. Optional parameters that are undefined are omitted from the URL.

→ [homeassistant/packages/traccar.yaml](../homeassistant/packages/traccar.yaml) · [traccar.en.md](../homeassistant/packages/traccar.en.md)

## 2. Call examples

### Minimal (location + time)

```yaml
service: rest_command.send_to_traccar
data:
  id: "<DEVICE_ID>"
  lat: 37.5665
  lon: 126.9780
  timestamp: "{{ (now().timestamp() * 1000) | int }}"
```

### With OBD telemetry

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

OBD sensor example: [espcomponents/colorado](https://github.com/eigger/espcomponents/tree/master/packages/display/colorado)

## 3. REST Command variables

| Variable | Required | Description |
|------|------|------|
| `id` | ✓ | Traccar device Unique ID |
| `lat` | | Latitude |
| `lon` | | Longitude |
| `timestamp` | | ISO 8601 UTC (`YYYY-MM-DDTHH:MM:SSZ`) or epoch ms |
| `speed` | | Speed (km/h or kn — follows Traccar unit setting) |
| `altitude` | | Altitude (m) |
| `bearing` | | Bearing (°) |
| `hdop` | | GPS accuracy (HDOP) |
| `batt` | | Battery (%) |
| `activity` | | Activity state (`unknown` · `unavailable` excluded) |
| `odometer` | | Odometer (km) |

`None`, `'None'`, and empty strings are automatically omitted from the URL.

## 4. Location update automation

Send to Traccar whenever the smartphone **Companion App** `device_tracker` changes. Two patterns depending on OBD integration.

| Pattern | Use case |
|------|------|
| [4.1 GPS + OBD](#41-gps--obd) | Enrich with vehicle OBD speed · odometer · engine load |
| [4.2 GPS only](#42-gps-only-no-obd) | No OBD — activity from GPS speed only |

Replace `<DEVICE_TRACKER>` · `<DEVICE_ID>` per device if they differ.

### 4.1 GPS + OBD

Enrich `activity` · `speed` · `odometer` with **OBD speed and engine load**.

### Behavior summary

```
device_tracker change  ──►  latitude present?  ──►  send_to_traccar
                              │
                              ├─ activity: engine ON → In Vehicle / speed-based Still·Walking·Running
                              ├─ speed: OBD first, else GPS×3.6 (km/h)
                              └─ odometer: OBD dashboard only when engine ON
```

### Entities (placeholders)

| Purpose | entity_id |
|------|-----------|
| GPS location | `device_tracker.<DEVICE_TRACKER>` |
| Battery | `sensor.<DEVICE_TRACKER>_battery_level` |
| OBD speed | `sensor.<OBD_DEVICE>_car_speed` |
| OBD engine load | `sensor.<OBD_DEVICE>_engine_load` |
| OBD odometer | `sensor.<OBD_DEVICE>_odometer` |

### Automation (YAML)

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

### activity · speed logic

| Condition | activity | speed |
|------|----------|-------|
| Engine load > 0 | `In Vehicle` | OBD `car_speed` preferred |
| Speed < 1 km/h | `Still` | OBD or GPS×3.6 |
| 1–7 km/h | `Walking` | |
| 7–15 km/h | `Running` | |
| ≥ 15 km/h | `In Vehicle` | |

- GPS `speed` attr is **m/s** → multiply by 3.6 for km/h
- Send `odometer` only when **engine ON** (engine load > 0) — avoids OBD bleed while walking
- `mode: queued` — avoids dropped sends on rapid location updates

### 4.2 GPS only (no OBD)

Send location · speed · activity from **Companion GPS** only, without OBD sensors. Use when Traccar device/`device_tracker` is **separate** from the OBD-linked terminal.

#### Behavior summary

```
device_tracker change  ──►  latitude present?  ──►  send_to_traccar
                              │
                              ├─ activity: GPS speed (km/h) → Still·Walking·Running·In Vehicle
                              └─ speed: GPS m/s × 3.6
```

#### Entities (placeholders)

| Purpose | entity_id |
|------|-----------|
| GPS location | `device_tracker.<DEVICE_TRACKER>` |

#### Automation (YAML)

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

#### activity · speed logic (GPS only)

| Speed (km/h) | activity |
|-------------|----------|
| No GPS | `Unknown` |
| < 2 | `Still` |
| 2 – 7 | `Walking` |
| 7 – 20 | `Running` |
| ≥ 20 | `In Vehicle` |

- **Thresholds differ** from [4.1 GPS + OBD](#41-gps--obd) — GPS-only uses wider low-speed bands (Still < 2 km/h)
- `odometer` · `batt` not sent — no OBD/battery sensors

## 5. Traccar-side checks

1. **Settings → Server** — enable OsmAnd protocol on port **5055**
2. **Devices** — Identifier = `id` sent from HA
3. After sending, confirm points on Traccar map/logs

## 6. Troubleshooting

| Symptom | Action |
|------|------|
| Device offline | Confirm `id` matches Traccar Unique ID |
| No location | Check `lat` · `lon` values and template errors |
| Wrong time | Check `timestamp` format (ISO UTC or ms epoch) |
| Connection failure | Check `<TRACCAR_IP>:5055` firewall and Docker port mapping |

## 7. Security

- Keep behind LAN or VPN; do not expose 5055 directly to the internet
- Location injection possible with `id` alone — use hard-to-guess Unique IDs
