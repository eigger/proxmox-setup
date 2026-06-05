# Home Assistant ↔ LubeLogger (REST Command)

**Language:** [한국어](ha-rest-command.md) · [English](ha-rest-command.en.md)

Add odometer and fuel records to the LubeLogger API via Home Assistant **REST Command**.

LXC install · port: [README.en.md](README.en.md) · packages YAML: [lubelogger.yaml](../homeassistant/packages/lubelogger.yaml)

## Environment (placeholders)

| Item | Example | Description |
|------|------|------|
| LubeLogger | `<LUBELOGGER_IP>` | LubeLogger LAN address |
| Port | `5000` | May vary per instance (Docker default is often `8080`, etc.) |
| Vehicle ID | `1` | From LubeLogger UI (`vehicleId`) |
| OBD (ESPHome) | [espcomponents/colorado](https://github.com/eigger/espcomponents/tree/master/packages/display/colorado) | Tab5 + vLinker BLE → HA sensors |

```
Home Assistant ──HTTP POST──► LubeLogger API
vLinker OBD2 ──BLE──► ESPHome (Colorado Tab5) ──MQTT──► Home Assistant
```

## 1. Prerequisites

1. LubeLogger **Settings → Enable Authentication** (Basic Auth)
2. Add `lubelogger_username`, `lubelogger_password` to `secrets.yaml` — [lubelogger.en.md](../homeassistant/packages/lubelogger.en.md)

## 2. packages — rest_command

Use HA **packages**. After placing the file, replace `<LUBELOGGER_IP>` and port in the URL with your actual values.

→ [homeassistant/packages/lubelogger.yaml](../homeassistant/packages/lubelogger.yaml) · [lubelogger.en.md](../homeassistant/packages/lubelogger.en.md)

### Headers

| Header | Value | Description |
|------|-----|------|
| `culture-invariant` | `true` | Treat numbers and dates in invariant culture format (API recommended) |

## 3. Call examples

### Odometer record

```yaml
service: rest_command.lubelogger_add_odometer
data:
  odometer: 45230
  notes: "월말 동기화"
```

With initial odometer:

```yaml
service: rest_command.lubelogger_add_odometer
data:
  odometer: 45230
  initial_odometer: 10000
```

### Fuel record

Follow [LubeLogger REST Command](ha-rest-command.en.md#2-packages--rest_command) and Opinet price lookup in [ha-fuel-opinet.en.md](ha-fuel-opinet.en.md). Start with Opinet **API key issuance**.

```yaml
service: rest_command.lubelogger_add_fuel
data:
  odometer: 45230
  fuel_consumed: 42.5
  cost: 85000
  is_full: true
  notes: "주유소 A"
```

## 4. OBD integration — register odometer on engine OFF

OBD sensors are collected on the ESPHome **Colorado Tab5** dashboard ([eigger/espcomponents — colorado](https://github.com/eigger/espcomponents/tree/master/packages/display/colorado)). M5Stack Tab5 + vLinker BLE OBD2 + `ble_elm327` expose RPM, fuel, odometer, etc. to HA. When **engine load drops near 0%** (engine OFF), that trip is recorded in LubeLogger.

```
vLinker OBD2 ──BLE──► ESP32 Tab5 (ESPHome) ──MQTT──► Home Assistant ──REST──► LubeLogger
```

### ESPHome (OBD sensor source)

Follow Colorado package README [Configuration Usage](https://github.com/eigger/espcomponents/tree/master/packages/display/colorado#configuration-usage) and [ble_elm327 Setup](https://github.com/eigger/espcomponents/tree/master/packages/display/colorado#ble_elm327-setup-vlinker-obd2).

```yaml
substitutions:
  name: "esp-colorado-tab5"          # → HA entity_id prefix: esp_colorado_tab5
  mac_vlinker: "<VLINKER_MAC>"

packages:
  remote:
    refresh: always
    url: https://github.com/eigger/espcomponents/
    files:
      - packages/display/colorado/colorado-tab5.yaml
```

For OBD sensors on a separate board, include only `colorado-ble-elm327.yaml`. Upstream also has a [LubeLogger Odometer Auto-Sync](https://github.com/eigger/espcomponents/tree/master/packages/display/colorado#lubelogger-odometer-auto-sync) example; this doc extends it with REST Command and notes fields.

### OBD sensors (HA entity_id)

Hyphens (`-`) in ESPHome `substitutions.name` become underscores (`_`) in HA entity_id.

| substitutions.name | HA prefix | Example entity_id |
|--------------------|-----------|----------------|
| `esp-colorado-tab5` | `esp_colorado_tab5` | `sensor.esp_colorado_tab5_engine_load` |

For other boards/names, replace `<OBD_DEVICE>` with that prefix.

| Purpose | entity_id |
|------|-----------|
| Engine load (%) | `sensor.<OBD_DEVICE>_engine_load` |
| Trip distance | `sensor.<OBD_DEVICE>_trip_distance` |
| Dashboard odometer | `sensor.<OBD_DEVICE>_odometer` |
| Fuel level (%) | `sensor.<OBD_DEVICE>_fuel_level` |
| Fuel level (L, GM) | `sensor.<OBD_DEVICE>_fuel_level_liters` |
| Engine run time (s) | `sensor.<OBD_DEVICE>_engine_run_time` |

### Behavior summary

```
Engine load < 1%  ──►  Trip distance > 0.1  ──►  LubeLogger odometer record
                         │
                         ├─ odometer: current dashboard value
                         ├─ initialOdometer: at departure (current − trip)
                         └─ notes: fuel · run time
```

### Automation (YAML)

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

| Item | Description |
|------|------|
| `mode: single` | Prevents re-trigger before previous run finishes |
| `initial_odometer` | `current odometer − trip distance` → dashboard at departure |
| `above: 0.1` | Ignore short stops/noise (unit follows OBD sensor config) |
| `response_variable` | (Optional) Inspect API response in Developer tools |

## 5. REST Command variables

### lubelogger_add_odometer

| Variable | Default | Description |
|------|--------|------|
| `vehicle_id` | `1` | Vehicle ID |
| `date` | today | `YYYY-MM-DD` |
| `odometer` | `0` | Odometer (km or mi — follows LubeLogger unit setting) |
| `notes` | `홈어시스턴트 자동 동기화` | Notes |
| `initial_odometer` | (none) | Optional. Initial odometer |

### lubelogger_add_fuel

| Variable | Default | Description |
|------|--------|------|
| `vehicle_id` | `1` | Vehicle ID |
| `date` | today | `YYYY-MM-DD` |
| `odometer` | `0` | Odometer at refuel |
| `fuel_consumed` | `0.0` | Fuel amount (L or gal) |
| `cost` | `0` | Cost |
| `is_full` | `false` | Full tank |
| `notes` | `홈어시스턴트 자동 동기화` | Notes |

## 6. Troubleshooting

| Symptom | Action |
|------|------|
| 401 Unauthorized | Check `secrets.yaml` credentials and LubeLogger auth enabled |
| Connection failure | Check `<LUBELOGGER_IP>`, port, HA ↔ LubeLogger LAN connectivity |
| Number format error | Keep `culture-invariant: "true"` header |
| Wrong vehicle | Match `vehicle_id` to LubeLogger UI vehicle ID |

## 7. Security

- Store username/password only in `secrets.yaml` — **do not commit to git**
- Do not expose LubeLogger directly to the internet (LAN or VPN only)
