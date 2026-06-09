# Home Assistant ↔ LubeLogger (오피넷 주유)

**Language:** [한국어](ha-fuel-opinet.md) · [English](ha-fuel-opinet.en.md)

OBD·위치 등으로 주유 이벤트를 감지한 뒤, [hass-opinet](https://github.com/eigger/hass-opinet) 통합의 `opinet.get_around`로 **현재 위치 주변 주유소 단가**를 조회하고 [LubeLogger](https://lubelogger.com)에 주유 기록을 넣습니다.

LXC 설치·포트: [README.md](README.md) · packages: [lubelogger.yaml](../homeassistant/packages/lubelogger.yaml)

```
person/위치 ──► opinet.get_around (hass-opinet) ──► HA 스크립트 ──► LubeLogger REST
                      ▲
               OBD 주행거리 ────────────────────────────────┘
```

| 단계 | 문서 |
|------|------|
| REST Command | [lubelogger.yaml](../homeassistant/packages/lubelogger.yaml) · [ha-rest-command.md](ha-rest-command.md#2-packages--rest_command) |
| 오피넷 API 키 | [1. 오피넷 API 키 발급](#1-오피넷-api-키-발급) |
| hass-opinet 설치 | [2. hass-opinet 통합](#2-hass-opinet-통합) |
| 금액 기반 주유 스크립트 | [3. 금액 기반 주유 스크립트](#3-금액-기반-주유-스크립트) |
| 주유 대시보드 카드 | [4. 주유 대시보드 카드](#4-주유-대시보드-카드) |

## 환경 (플레이스홀더)

| 항목 | 예시 | 설명 |
|------|------|------|
| 위치 엔티티 | `person.<PERSON>` | 주유 시점 GPS — `person.*` 또는 `device_tracker.*` |
| OBD 주행거리 | `sensor.<OBD_DEVICE>_odometer` | [Colorado OBD](https://github.com/eigger/espcomponents/tree/master/packages/display/colorado) |
| 유종 코드 | `B027` | 휘발유 (`D047` 경유, `B034` 고급휘발유) |
| 검색 반경 | `500` | 미터 — 주유소가 없으면 스크립트 중단 |

## 1. 오피넷 API 키 발급

한국석유공사 **오피넷 유가정보 API**는 무료·유료로 구분되며, 호출 시 **인증키(Key)** 가 필요합니다. 키는 [§2](#2-hass-opinet-통합) 통합 구성 UI에 입력합니다.

- 이용 안내: [오픈 API 소개](https://www.opinet.co.kr/user/custapi/openApiIntro.do)
- API 목록·무료 신청: [유가 정보 API](https://www.opinet.co.kr/user/custapi/custApiInfo.do)
- 데이터 문의: (052) 216-2514, price@knoc.co.kr

### 발급 절차

1. [오피넷](https://www.opinet.co.kr) **회원가입**
2. [오픈 API 이용 안내](https://www.opinet.co.kr/user/custapi/openApiIntro.do) → **인증키 발급**
3. [유가 정보 API](https://www.opinet.co.kr/user/custapi/custApiInfo.do) → **무료 API 이용 신청**
4. (권장) 무료 API 이용가이드 PDF 다운로드

### 주유 등록에 쓸 API

| API | 용도 |
|------|------|
| 반경 내 주유소 검색 (`aroundAll`) | GPS 기준 근처 주유소·단가 → [§3 스크립트](#3-금액-기반-주유-스크립트) |
| 주유소 상세정보(ID) | 관심 주유소를 hass-opinet에 등록할 때 (선택) |

유종 코드(`PRODCD`): `B027` 휘발유, `D047` 경유, `B034` 고급휘발유

## 2. hass-opinet 통합

**[hass-opinet](https://github.com/eigger/hass-opinet)** 커스텀 통합을 사용합니다. API 키·주유소 검색·`opinet.get_around` 등 오피넷 API를 HA 서비스·센서로 제공합니다.

### 설치

1. HACS **사용자 지정 저장소**에 `https://github.com/eigger/hass-opinet` 추가하거나, `custom_components/opinet`을 HA `custom_components/`에 복사
2. Home Assistant **재시작**
3. **설정 → 기기 및 서비스 → 통합구성요소 추가 → Opinet 유가정보** → [§1](#1-오피넷-api-키-발급) API 키 입력

구성 시 **전국 평균가 센서**가 생성됩니다. 관심 주유소를 **이름 검색** 또는 **주유소 ID**로 추가하면 해당 주유소 유가·지도 표시 센서도 생깁니다. [§3](#3-금액-기반-주유-스크립트) 금액 기반 주유에는 **반드시 필요하지 않습니다** — `opinet.get_around`가 실행 시점 위치로 주변 주유소를 조회합니다.

### secrets.yaml (LubeLogger)

**git에 커밋하지 않습니다.**

```yaml
# LubeLogger (ha-rest-command.md)
lubelogger_username: "<LUBELOGGER_USER>"
lubelogger_password: "<LUBELOGGER_PASSWORD>"
```

오피넷 API 키는 hass-opinet **통합 구성 UI**에 저장됩니다 (`secrets.yaml` URL 방식 불필요).

### opinet.get_around (스크립트에서 사용)

위치 엔티티(`person.*`, `device_tracker.*`) 기준 반경 내 주유소를 조회합니다. 응답은 `{"oil": [ ... ]}` 형태이며, 각 항목에 `OS_NM`(상호), `PRICE`(원/L) 등이 포함됩니다.

```yaml
action: opinet.get_around
data:
  entity_id: person.<PERSON>
  radius: 500
  prodcd: B027
  sort: "2"
response_variable: response
```

| 항목 | 설명 |
|------|------|
| `entity_id` | 위치 엔티티 — 생략 시 HA 홈 좌표 |
| `radius` | 검색 반경 (m) |
| `prodcd` | 유종 코드 |
| `sort` | `"2"` — 가격순 (오피넷 API 정렬 코드) |

무료 API 일일 호출 한도 **1,500건/일** — [이용 안내](https://www.opinet.co.kr/user/custapi/custApiInfo.do) 준수.

## 3. 금액 기반 주유 스크립트

결제 **금액(원)** 을 입력하면, **현재 위치 주변** 최저가(가격순 1번) 주유소 단가와 OBD **주행거리**로 주유량(L)을 역산해 `rest_command.lubelogger_add_fuel`을 호출합니다. **반경 내 주유소가 없으면** 기록하지 않고 중단합니다.

```
fuel_consumed = 주유 금액 ÷ response.oil[0].PRICE
```

OBD 주행거리: [espcomponents/colorado](https://github.com/eigger/espcomponents/tree/master/packages/display/colorado) — `<OBD_DEVICE>` (예: `esp_colorado_tab5`)

### scripts.yaml

`person.<PERSON>`, `sensor.<OBD_DEVICE>_odometer`를 환경에 맞게 바꿉니다.

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

### 호출

**설정 → 자동화 및 장면 → 스크립트**에서 실행하거나, [§4 대시보드 카드](#4-주유-대시보드-카드) 버튼·자동화에서 `script.lubelogger`를 호출합니다.

```yaml
action: script.lubelogger
data:
  input_cost: 100000
```

### 동작 설명

| 항목 | 설명 |
|------|------|
| `input_cost` | 실제 결제 금액 (원) |
| `opinet.get_around` | [§2](#2-hass-opinet-통합) — 현재 위치 기준 주변 주유소·단가 실시간 조회 |
| `response.oil[0]` | `sort: "2"`(가격순) 첫 번째 주유소 |
| `condition` | 주변 주유소 없음 → LubeLogger 호출 안 함 |
| `sensor.<OBD_DEVICE>_odometer` | Colorado OBD 계기판 주행거리 |
| `is_full: false` | 금액 입력 방식 — 가득 주유 여부는 별도 판단 |
| 경유·고급휘발유 | `prodcd`를 `D047`·`B034`로 변경 |

> `scripts.yaml` 키가 `lubelogger`이면 entity_id는 `script.lubelogger`입니다.

## 4. 주유 대시보드 카드

[§3 금액 기반 주유 스크립트](#3-금액-기반-주유-스크립트)를 Lovelace **그리드 + 버튼**으로 배치합니다. 고정 금액(5만·10만)은 한 번에 실행하고, **기타 주유**는 탭 시 금액 입력 UI가 열립니다.

**대시보드 → 편집 → 수동(YAML)** 또는 **스택/섹션 → 카드 추가 → 수동**:

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

### 동작

| 버튼 | 동작 |
|------|------|
| 5만원 / 10만원 | `input_cost` 고정 → 즉시 LubeLogger 기록 |
| 기타 주유 | `tap_action` 없음 → 스크립트 **필드 입력** 다이얼로그 (임의 금액) |

금액 프리셋은 `input_cost` 값만 바꿔 추가하면 됩니다.

## 5. 보안

- LubeLogger 계정은 `secrets.yaml`에만 보관
- 오피넷 API 키는 hass-opinet 통합 구성에 저장 — **git에 커밋하지 않음**
- 무료 API 일일 호출 한도 — [이용 안내](https://www.opinet.co.kr/user/custapi/custApiInfo.do) 준수
