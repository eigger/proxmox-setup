# Home Assistant — 주유 등록 (오피넷 + LubeLogger)

OBD·위치 등으로 주유 이벤트를 감지한 뒤, [오피넷(Opinet)](https://www.opinet.co.kr) API로 단가를 조회하고 [LubeLogger](https://lubelogger.com)에 주유 기록을 넣는 흐름을 정리합니다.

```
오피넷 REST 센서 (단가) ──► HA 스크립트 (금액 → 주유량) ──► LubeLogger REST
         ▲                          ▲
    OBD 주행거리 ────────────────────┘
```

| 단계 | 문서 |
|------|------|
| REST Command 정의 | [ha-rest-command.md §2](ha-rest-command.md#2-configurationyaml--rest_command) (`lubelogger_add_fuel`) |
| 오피넷 API 키 | 이 문서 §1 |
| **주유소 단가 센서** | 이 문서 §3 |
| **금액 기반 주유 스크립트** | 이 문서 §4 |
| **주유 대시보드 카드** | 이 문서 §5 |

## 1. 오피넷 API 키 발급

한국석유공사 **오피넷 유가정보 API**는 무료·유료로 구분되며, 호출 시 공사에서 부여한 **인증키(Key)** 가 필요합니다.

- 이용 안내: [오픈 API 소개](https://www.opinet.co.kr/user/custapi/openApiIntro.do)
- API 목록·무료 신청: [유가 정보 API](https://www.opinet.co.kr/user/custapi/custApiInfo.do)
- 데이터 문의: (052) 216-2514, price@knoc.co.kr

### 발급 절차

1. [오피넷](https://www.opinet.co.kr) **회원가입**
2. [오픈 API 이용 안내](https://www.opinet.co.kr/user/custapi/openApiIntro.do) → **인증키 발급**
3. [유가 정보 API](https://www.opinet.co.kr/user/custapi/custApiInfo.do) → **무료 API 이용 신청**
4. 발급받은 인증키를 `secrets.yaml`에 저장 (§2)
5. (권장) 무료 API 이용가이드 PDF 다운로드

### 주유 등록에 쓸 무료 API

| API | 용도 |
|------|------|
| [주유소 상세정보(ID)](https://www.opinet.co.kr/user/custapi/openApiInfoDtl.do?apiId=1) | 주유소 ID로 **유종별 현재 단가** 조회 → §3 REST 센서 |
| 반경 내 주유소 검색 | GPS 기준 근처 주유소·ID 탐색 |
| 전국/지역 평균가격 | 단가 fallback |

유종 코드(`PRODCD`): `B027` 휘발유, `D047` 경유, `B034` 고급휘발유

## 2. secrets.yaml

**git에 커밋하지 않습니다.**

```yaml
# LubeLogger (ha-rest-command.md)
lubelogger_username: "<LUBELOGGER_USER>"
lubelogger_password: "<LUBELOGGER_PASSWORD>"

# 오피넷 — 주유소 상세 API URL (인증키·주유소 ID 포함)
opinet_nanuri_url: "https://www.opinet.co.kr/api/detailById.do?code=<API>&id=<주유소ID>&out=json"
```

| 플레이스홀더 | 설명 |
|-------------|------|
| `<API>` | §1에서 발급받은 오피넷 인증키 |
| `<주유소ID>` | 오피넷 주유소 ID (예: `A0010207`) — 웹·앱 **관심 주유소** 또는 [반경 검색 API](https://www.opinet.co.kr/user/custapi/custApiInfo.do)로 확인 |

- URL 전체를 secret에 두면 `configuration.yaml`에 키가 노출되지 않음
- 다른 주유소는 `opinet_<이름>_url` secret을 추가하면 됨

### API 동작 확인

브라우저에서 `opinet_nanuri_url`과 동일한 URL을 열어 JSON이 오는지 확인합니다.

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

`PRICE`는 **원/L** (LubeLogger `cost` = `fuel_consumed × 단가`).

## 3. 주유소 단가 REST 센서

[RESTful 센서](https://www.home-assistant.io/integrations/rest/)로 **주유소 상세 API** 응답에서 유종별 단가를 파싱합니다. 1시간(`scan_interval: 3600`)마다 갱신해 API 호출 한도를 줄입니다.

`configuration.yaml` (또는 `packages/`):

```yaml
rest:
  - resource: !secret opinet_nanuri_url
    scan_interval: 3600
    sensor:
      - name: "나누리 SK 휘발유"
        unique_id: nanuri_sk_b027
        value_template: >
          {% if value_json is defined and value_json.RESULT is defined and value_json.RESULT.OIL is defined %}
            {{ (value_json.RESULT.OIL[0].OIL_PRICE | selectattr('PRODCD', 'eq', 'B027') | first).PRICE | int }}
          {% else %}
            {{ states('sensor.nanuri_sk_hwibalyu') }}
          {% endif %}
        icon: mdi:gas-station
        unit_of_measurement: KRW
        force_update: true

      - name: "나누리 SK 경유"
        unique_id: nanuri_sk_d047
        value_template: >
          {% if value_json is defined and value_json.RESULT is defined and value_json.RESULT.OIL is defined %}
            {{ (value_json.RESULT.OIL[0].OIL_PRICE | selectattr('PRODCD', 'eq', 'D047') | first).PRICE | int }}
          {% else %}
            {{ states('sensor.nanuri_sk_gyeongyu') }}
          {% endif %}
        icon: mdi:gas-station
        unit_of_measurement: KRW
        force_update: true
```

### 고급휘발유 (선택)

필요 시 아래 블록을 주석 해제합니다.

```yaml
      - name: "나누리 SK 고급휘발유"
        unique_id: nanuri_sk_b034
        value_template: >
          {% if value_json is defined and value_json.RESULT is defined and value_json.RESULT.OIL is defined %}
            {{ (value_json.RESULT.OIL[0].OIL_PRICE | selectattr('PRODCD', 'eq', 'B034') | first).PRICE | int }}
          {% else %}
            {{ states('sensor.nanuri_sk_gogeubhwbalyu') }}
          {% endif %}
        icon: mdi:gas-station
        unit_of_measurement: KRW
        force_update: true
```

### 동작 설명

| 항목 | 설명 |
|------|------|
| `resource: !secret opinet_nanuri_url` | `detailById` 전체 URL (§2) |
| `selectattr('PRODCD', 'eq', 'B027')` | JSON 배열에서 유종 코드로 단가 추출 |
| `{% else %}` 분기 | API 실패·파싱 오류 시 **이전 값 유지** |
| `force_update: true` | 값이 같아도 상태 업데이트 (자동화 트리거용) |
| entity_id | HA가 이름에서 자동 생성 (예: `sensor.nanuri_sk_hwibalyu`) — fallback의 entity_id와 일치해야 함 |

### 다른 주유소 추가

1. 오피넷에서 `<주유소ID>` 확인
2. `secrets.yaml`에 `opinet_<이름>_url` 추가
3. `rest:` 블록을 복사해 `resource`·`unique_id`·센서 이름만 변경

## 4. 금액 기반 주유 스크립트

결제 **금액(원)** 만 입력하면, §3 **휘발유 단가 센서**와 OBD **주행거리**로 주유량(L)을 역산해 `rest_command.lubelogger_add_fuel`을 호출합니다.

```
fuel_consumed = 주유 금액 ÷ 리터당 단가 (sensor.nanuri_sk_hwibalyu)
```

OBD 주행거리: [espcomponents/colorado](https://github.com/eigger/espcomponents/tree/master/packages/display/colorado) — entity 접두사 `<OBD_DEVICE>` (예: `esp_colorado_tab5`)

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

### 호출

**설정 → 자동화 및 장면 → 스크립트**에서 실행하거나, §5 **대시보드 버튼**·자동화에서 `script.lubelogger`를 호출합니다.

```yaml
service: script.lubelogger
data:
  input_cost: 70000
```

### 동작 설명

| 항목 | 설명 |
|------|------|
| `input_cost` | 실제 결제 금액 (원) |
| `sensor.nanuri_sk_hwibalyu` | §3 나누리 SK 휘발유 단가 (원/L) |
| `sensor.<OBD_DEVICE>_odometer` | Colorado OBD 계기판 주행거리 |
| `is_full: false` | 금액 입력 방식 — 가득 주유 여부는 별도 판단 |
| 단가 0 | API·센서 오류 시 `fuel_consumed: 0.0` — LubeLogger 기록 전 단가 확인 권장 |

> `scripts.yaml` 키가 `lubelogger`이면 entity_id는 `script.lubelogger`입니다.

## 5. 주유 대시보드 카드

§4 스크립트를 Lovelace **그리드 + 버튼**으로 배치합니다. 고정 금액(5만·10만)은 한 번에 실행하고, **기타 주유**는 탭 시 금액 입력 UI가 열립니다.

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

## 6. 보안·이용

- `opinet_*_url`·API 키는 `secrets.yaml`에만 보관
- 무료 API 일일 호출 한도 — `scan_interval` 조절·가이드 PDF 확인
- [저작권·이용 안내](https://www.opinet.co.kr/user/custapi/custApiInfo.do) 준수
