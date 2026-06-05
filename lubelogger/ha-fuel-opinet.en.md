# Home Assistant ↔ LubeLogger (Opinet fuel)

**Language:** [한국어](ha-fuel-opinet.md) · [English](ha-fuel-opinet.en.md)

After detecting a refuel event via OBD, location, etc., look up unit prices with the [Opinet](https://www.opinet.co.kr) API and add a fuel record to [LubeLogger](https://lubelogger.com).

LXC install · port: [README.en.md](README.en.md) · packages: [lubelogger.yaml](../homeassistant/packages/lubelogger.yaml), [opinet.yaml](../homeassistant/packages/opinet.yaml)

```
Opinet REST sensors (prices) ──► HA script (amount → volume) ──► LubeLogger REST
         ▲                          ▲
    OBD odometer ────────────────────┘
```

| Step | Document |
|------|------|
| REST Command | [lubelogger.yaml](../homeassistant/packages/lubelogger.yaml) · [ha-rest-command.en.md](ha-rest-command.en.md#2-packages--rest_command) |
| Opinet API key | [1. Opinet API key](#1-opinet-api-key) |
| Gas station price sensors | [3. Gas station price REST sensors](#3-gas-station-price-rest-sensors) |
| Amount-based fuel script | [4. Amount-based fuel script](#4-amount-based-fuel-script) |
| Fuel dashboard card | [5. Fuel dashboard card](#5-fuel-dashboard-card) |

## 1. Opinet API key

The Korea National Oil Corporation **Opinet fuel price API** has free and paid tiers; calls require an **authentication key** issued by the corporation.

- Usage guide: [Open API introduction](https://www.opinet.co.kr/user/custapi/openApiIntro.do)
- API list · free signup: [Fuel price API](https://www.opinet.co.kr/user/custapi/custApiInfo.do)
- Data inquiries: (052) 216-2514, price@knoc.co.kr

### Issuance steps

1. **Sign up** at [Opinet](https://www.opinet.co.kr)
2. [Open API guide](https://www.opinet.co.kr/user/custapi/openApiIntro.do) → **Issue authentication key**
3. [Fuel price API](https://www.opinet.co.kr/user/custapi/custApiInfo.do) → **Apply for free API**
4. Store the issued key in `secrets.yaml` ([2. secrets.yaml](#2-secretsyaml))
5. (Recommended) Download the free API usage guide PDF

### Free APIs for fuel logging

| API | Purpose |
|------|------|
| [Gas station details (ID)](https://www.opinet.co.kr/user/custapi/openApiInfoDtl.do?apiId=1) | **Current unit prices by fuel type** via station ID → [3. REST sensors](#3-gas-station-price-rest-sensors) |
| Nearby station search | Find nearby stations and IDs by GPS |
| National/regional average price | Price fallback |

Fuel type codes (`PRODCD`): `B027` gasoline, `D047` diesel, `B034` premium gasoline

## 2. secrets.yaml

**Do not commit to git.**

```yaml
# LubeLogger (ha-rest-command.md)
lubelogger_username: "<LUBELOGGER_USER>"
lubelogger_password: "<LUBELOGGER_PASSWORD>"

# 오피넷 — 주유소 상세 API URL (인증키·주유소 ID 포함)
opinet_nanuri_url: "https://www.opinet.co.kr/api/detailById.do?code=<API>&id=<주유소ID>&out=json"
```

| Placeholder | Description |
|-------------|------|
| `<API>` | Authentication key from [1. Opinet API key](#1-opinet-api-key) |
| `<주유소ID>` | Opinet station ID (e.g. `A0010207`) — web/app **favorite station** or [radius search API](https://www.opinet.co.kr/user/custapi/custApiInfo.do) |

- Storing the full URL in `secrets.yaml` keeps the API key out of packages YAML
- Add `opinet_<name>_url` secrets for other stations

### Verify API response

Open the same URL as `opinet_nanuri_url` in a browser and confirm JSON is returned.

```json
{
  "RESULT": {
    "OIL": [{
      "OIL_PRICE": [
        { "PRODCD": "B027", "PRICE": "1745" },
        { "PRODCD": "D047", "PRICE": "1580" }
      ]
    }]
  }
}
```

`PRICE` is **KRW/L** (LubeLogger `cost` = `fuel_consumed × unit price`).

## 3. Gas station price REST sensors

Parse per-fuel prices from the **gas station details API** with a [RESTful sensor](https://www.home-assistant.io/integrations/rest/). Refresh every hour (`scan_interval: 3600`) to reduce API call volume.

Use HA **packages**:

→ [homeassistant/packages/opinet.yaml](../homeassistant/packages/opinet.yaml) · [opinet.en.md](../homeassistant/packages/opinet.en.md)

`secrets.yaml` must define `opinet_nanuri_url` ([2. secrets.yaml](#2-secretsyaml)).

| name | entity_id (example) | Fuel (`PRODCD`) |
|------|----------------|-----------------|
| 나누리 SK 휘발유 | `sensor.nanuri_sk_hwibalyu` | B027 |
| 나누리 SK 경유 | `sensor.nanuri_sk_gyeongyu` | D047 |
| 나누리 SK 고급휘발유 | `sensor.nanuri_sk_gogeubhwbalyu` | B034 |

### How it works

| Item | Description |
|------|------|
| `resource: !secret opinet_nanuri_url` | Full `detailById` URL ([2. secrets.yaml](#2-secretsyaml)) |
| `selectattr('PRODCD', 'eq', 'B027')` | Extract price from JSON array by fuel code |
| `{% else %}` branch | **Keep previous value** on API/parsing failure |
| `force_update: true` | Update state even when value unchanged (for automation triggers) |
| entity_id | Auto-generated from name (e.g. `sensor.nanuri_sk_hwibalyu`) — must match fallback entity_id |

### Add another station

1. Look up `<주유소ID>` on Opinet
2. Add `opinet_<name>_url` to `secrets.yaml`
3. Copy the `rest:` block and change `resource`, `unique_id`, and sensor name only

## 4. Amount-based fuel script

Enter only the payment **amount (KRW)**; the script derives volume (L) from [3. price sensors](#3-gas-station-price-rest-sensors) and OBD **odometer**, then calls `rest_command.lubelogger_add_fuel`.

```
fuel_consumed = refuel amount ÷ price per liter (sensor.nanuri_sk_hwibalyu)
```

OBD odometer: [espcomponents/colorado](https://github.com/eigger/espcomponents/tree/master/packages/display/colorado) — entity prefix `<OBD_DEVICE>` (e.g. `esp_colorado_tab5`)

### scripts.yaml

```yaml
lubelogger:
  alias: LubeLogger 금액 기반 주유 기록 자동 계산
  description: 주유 금액과 오피넷 단가로 주유량을 계산해 LubeLogger에 기록합니다.
  icon: mdi:gas-station
  fields:
    input_cost:
      name: 주유 금액
      description: 실제 지불한 총 주유 금액(원)을 입력하세요.
      example: 70000
      required: true
      selector:
        number:
          min: 0
          max: 500000
          step: 1000
          mode: box
          unit_of_measurement: KRW
  sequence:
    - action: rest_command.lubelogger_add_fuel
      data:
        vehicle_id: 1
        odometer: "{{ states('sensor.<OBD_DEVICE>_odometer') | int(0) }}"
        cost: "{{ input_cost | int }}"
        fuel_consumed: >-
          {% set price = states('sensor.nanuri_sk_hwibalyu') | float(0) %}
          {% if price > 0 %}
            {{ (input_cost | float / price) | round(2) }}
          {% else %}
            0.0
          {% endif %}
        is_full: false
        notes: >-
          HA 스크립트 자동 계산 (리터당 {{ states('sensor.nanuri_sk_hwibalyu') }}원)
```

### Invocation

Run from **Settings → Automations & scenes → Scripts**, or call `script.lubelogger` from [5. dashboard card](#5-fuel-dashboard-card) buttons or automations.

```yaml
service: script.lubelogger
data:
  input_cost: 70000
```

### How it works

| Item | Description |
|------|------|
| `input_cost` | Actual payment amount (KRW) |
| `sensor.nanuri_sk_hwibalyu` | [3.](#3-gas-station-price-rest-sensors) gasoline price (KRW/L). For premium, use `sensor.nanuri_sk_gogeubhwbalyu` |
| `sensor.<OBD_DEVICE>_odometer` | Colorado OBD dashboard odometer |
| `is_full: false` | Amount entry mode — full tank is judged separately |
| Price 0 | API/sensor error → `fuel_consumed: 0.0` — verify price before LubeLogger record |

> If `scripts.yaml` key is `lubelogger`, entity_id is `script.lubelogger`.

## 5. Fuel dashboard card

Place [4. amount-based fuel script](#4-amount-based-fuel-script) on Lovelace as a **grid + buttons**. Fixed amounts (50k · 100k KRW) run immediately; **Other** opens the amount input UI on tap.

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

## 6. Security

- Keep `opinet_*_url` and API keys only in `secrets.yaml`
- Free API daily call limits — tune `scan_interval` and follow the [usage guide](https://www.opinet.co.kr/user/custapi/custApiInfo.do)
