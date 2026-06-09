# Home Assistant ↔ LubeLogger (Opinet fuel)

**Language:** [한국어](ha-fuel-opinet.md) · [English](ha-fuel-opinet.en.md)

After detecting a refuel event via OBD, location, etc., look up **nearby gas station prices** with the [hass-opinet](https://github.com/eigger/hass-opinet) integration’s `opinet.get_around` service and add a fuel record to [LubeLogger](https://lubelogger.com).

LXC install · port: [README.en.md](README.en.md) · packages: [lubelogger.yaml](../homeassistant/packages/lubelogger.yaml)

```
person/location ──► opinet.get_around (hass-opinet) ──► HA script ──► LubeLogger REST
                           ▲
                    OBD odometer ──────────────────────────────────┘
```

| Step | Document |
|------|------|
| REST Command | [lubelogger.yaml](../homeassistant/packages/lubelogger.yaml) · [ha-rest-command.en.md](ha-rest-command.en.md#2-packages--rest_command) |
| Opinet API key | [1. Opinet API key](#1-opinet-api-key) |
| hass-opinet setup | [2. hass-opinet integration](#2-hass-opinet-integration) |
| Amount-based fuel script | [3. Amount-based fuel script](#3-amount-based-fuel-script) |
| Fuel dashboard card | [4. Fuel dashboard card](#4-fuel-dashboard-card) |

## Environment (placeholders)

| Item | Example | Description |
|------|---------|-------------|
| Location entity | `person.<PERSON>` | GPS at refuel time — `person.*` or `device_tracker.*` |
| OBD odometer | `sensor.<OBD_DEVICE>_odometer` | [Colorado OBD](https://github.com/eigger/espcomponents/tree/master/packages/display/colorado) |
| Fuel code | `B027` | Gasoline (`D047` diesel, `B034` premium) |
| Search radius | `500` | Meters — script stops if no station found |

## 1. Opinet API key

The Korea National Oil Corporation **Opinet fuel price API** requires an **authentication key**. Enter the key in the [§2](#2-hass-opinet-integration) integration UI.

- Usage guide: [Open API introduction](https://www.opinet.co.kr/user/custapi/openApiIntro.do)
- API list · free signup: [Fuel price API](https://www.opinet.co.kr/user/custapi/custApiInfo.do)
- Data inquiries: (052) 216-2514, price@knoc.co.kr

### Issuance steps

1. **Sign up** at [Opinet](https://www.opinet.co.kr)
2. [Open API guide](https://www.opinet.co.kr/user/custapi/openApiIntro.do) → **Issue authentication key**
3. [Fuel price API](https://www.opinet.co.kr/user/custapi/custApiInfo.do) → **Apply for free API**
4. (Recommended) Download the free API usage guide PDF

### APIs used for fuel logging

| API | Purpose |
|------|------|
| Nearby station search (`aroundAll`) | GPS-based stations and prices → [§3 script](#3-amount-based-fuel-script) |
| Gas station details (ID) | When registering favorite stations in hass-opinet (optional) |

Fuel type codes (`PRODCD`): `B027` gasoline, `D047` diesel, `B034` premium gasoline

## 2. hass-opinet integration

Use the **[hass-opinet](https://github.com/eigger/hass-opinet)** custom integration instead of legacy REST sensors in packages. It exposes Opinet API keys, station search, `opinet.get_around`, and optional price sensors.

### Install

1. Add `https://github.com/eigger/hass-opinet` as a HACS custom repository, or copy `custom_components/opinet` into HA `custom_components/`
2. **Restart** Home Assistant
3. **Settings → Devices & services → Add integration → Opinet 유가정보** → enter the API key from [§1](#1-opinet-api-key)

National average price sensors are created on setup. You can add favorite stations by **name search** or **station ID** for map and price sensors. **Not required** for [§3](#3-amount-based-fuel-script) — `opinet.get_around` queries nearby stations at run time.

### secrets.yaml (LubeLogger)

**Do not commit to git.**

```yaml
# LubeLogger (ha-rest-command.md)
lubelogger_username: "<LUBELOGGER_USER>"
lubelogger_password: "<LUBELOGGER_PASSWORD>"
```

The Opinet API key is stored in the hass-opinet **integration config** (no `secrets.yaml` URL).

### opinet.get_around (used by the script)

Search stations within a radius of a location entity (`person.*`, `device_tracker.*`). Response shape: `{"oil": [ ... ]}` with `OS_NM` (name), `PRICE` (KRW/L), etc.

```yaml
action: opinet.get_around
data:
  entity_id: person.<PERSON>
  radius: 500
  prodcd: B027
  sort: "2"
response_variable: response
```

| Item | Description |
|------|-------------|
| `entity_id` | Location entity — omit to use HA home coordinates |
| `radius` | Search radius (m) |
| `prodcd` | Fuel type code |
| `sort` | `"2"` — sort by price (Opinet API sort code) |

Free API limit **1,500 calls/day** — follow the [usage guide](https://www.opinet.co.kr/user/custapi/custApiInfo.do).

## 3. Amount-based fuel script

Enter the payment **amount (KRW)**; the script derives volume (L) from the **cheapest nearby station** (`sort: "2"`, first result) and OBD **odometer**, then calls `rest_command.lubelogger_add_fuel`. **Stops without recording** if no station is found in range.

```
fuel_consumed = refuel amount ÷ response.oil[0].PRICE
```

OBD odometer: [espcomponents/colorado](https://github.com/eigger/espcomponents/tree/master/packages/display/colorado) — `<OBD_DEVICE>` (e.g. `esp_colorado_tab5`)

### scripts.yaml

Replace `person.<PERSON>` and `sensor.<OBD_DEVICE>_odometer` for your environment.

```yaml
lubelogger:
  alias: LubeLogger 금액 기반 주유 기록 자동 계산
  icon: mdi:gas-station
  description: 주변 주유소 정보를 바탕으로 주유량을 계산하여 LubeLogger에 기록합니다. (주변 주유소가 없으면 실행 중단)
  fields:
    input_cost:
      name: 주유 금액
      description: 실제 지불한 총 주유 금액(원)을 입력하세요.
      example: 100000
      required: true
      selector:
        number:
          min: 1000
          max: 150000
          step: 1000
          mode: box
          unit_of_measurement: KRW
  sequence:
    - action: opinet.get_around
      data:
        entity_id: person.<PERSON>
        radius: 500
        prodcd: B027
        sort: "2"
      response_variable: response
    - condition: template
      value_template: "{{ response.oil is defined and response.oil | length > 0 }}"
    - action: rest_command.lubelogger_add_fuel
      data:
        vehicle_id: 1
        odometer: "{{ states('sensor.<OBD_DEVICE>_odometer') | int(0) }}"
        cost: "{{ input_cost | int }}"
        fuel_consumed: >
          {% set price_per_liter = response.oil[0].PRICE | float(0) %}
          {% if price_per_liter > 0 %}
            {{ (input_cost | float / price_per_liter) | round(2) }}
          {% else %}
            0.0
          {% endif %}
        is_full: false
        notes: |
          HA 입력 ({{ response.oil[0].OS_NM }}, 리터당 {{ response.oil[0].PRICE }}원)
```

### Invocation

Run from **Settings → Automations & scenes → Scripts**, or call `script.lubelogger` from [§4 dashboard card](#4-fuel-dashboard-card) buttons or automations.

```yaml
action: script.lubelogger
data:
  input_cost: 100000
```

### How it works

| Item | Description |
|------|-------------|
| `input_cost` | Actual payment amount (KRW) |
| `opinet.get_around` | [§2](#2-hass-opinet-integration) — live nearby stations and prices |
| `response.oil[0]` | First station with `sort: "2"` (by price) |
| `condition` | No nearby station → skip LubeLogger call |
| `sensor.<OBD_DEVICE>_odometer` | Colorado OBD dashboard odometer |
| `is_full: false` | Amount entry mode — full tank judged separately |
| Diesel / premium | Change `prodcd` to `D047` / `B034` |

> If `scripts.yaml` key is `lubelogger`, entity_id is `script.lubelogger`.

## 4. Fuel dashboard card

Place [§3 amount-based fuel script](#3-amount-based-fuel-script) on Lovelace as a **grid + buttons**. Fixed amounts (50k · 100k KRW) run immediately; **Other** opens the amount input UI on tap.

**Dashboard → Edit → Manual (YAML)** or **Stack/Section → Add card → Manual**:

```yaml
type: grid
square: false
cards:
  - type: button
    entity: script.lubelogger
    name: 5만원 주유
    icon: mdi:gas-station
    show_name: true
    show_icon: true
    tap_action:
      action: perform-action
      perform_action: script.lubelogger
      data:
        input_cost: 50000

  - type: button
    entity: script.lubelogger
    name: 10만원 주유
    icon: mdi:gas-station
    show_name: true
    show_icon: true
    tap_action:
      action: perform-action
      perform_action: script.lubelogger
      data:
        input_cost: 100000

  - type: button
    entity: script.lubelogger
    name: 기타 주유
    icon: mdi:gas-station
    show_name: true
    show_icon: true
```

### Behavior

| Button | Action |
|------|------|
| 5만원 / 10만원 | Fixed `input_cost` → immediate LubeLogger record |
| 기타 주유 | No `tap_action` → script **field input** dialog (any amount) |

Add more presets by changing `input_cost` only.

## 5. Security

- Keep LubeLogger credentials in `secrets.yaml` only
- Opinet API key lives in hass-opinet integration config — **do not commit**
- Free API daily call limits — follow the [usage guide](https://www.opinet.co.kr/user/custapi/custApiInfo.do)
