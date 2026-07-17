# Stash

**Language:** [한국어](README.md) · [English](README.en.md)

[Stash](https://github.com/eigger/stash) — 셀프호스팅 가정용 재고·자산 및 바코드 관리 웹 앱. 기존 제품 바코드(UPC/EAN), QR 코드, Matter 페어링 코드를 스캔하여 위치 및 수량을 추적하며, 유통기한 알림 및 라벨 출력을 지원합니다.

## 설치

Proxmox VE **LXC** 설치 스크립트:

1. Proxmox 호스트 **Shell**에서 아래 명령 실행
2. 마법사 설정에 따라 LXC 생성

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/eigger/stash/master/proxmox/ct/stash.sh)"
```

설치 후 웹 UI: `http://<STASH_IP>` (기본 포트 **80**)

### 초기 설정

1. 첫 접속 시 사용자 테이블이 비어있으면 **최초 관리자 생성(Bootstrap Admin)** 페이지가 표시됩니다. 이름·이메일·비밀번호를 설정하여 관리자 계정을 생성합니다.
2. 하단 네비게이션 **더보기(More)** → **설정(Settings)**에서 시스템 기본 설정(통화, 기본 외부 제품 조회 제공자 등)을 구성할 수 있습니다.

## Home Assistant 연동 (라벨 인쇄)

Stash는 라벨 인쇄 및 재고 변경 이벤트를 외부로 전송할 수 있는 **아웃바운드 인벤토리 웹훅(Outbound Inventory Webhook)** 기능을 지원합니다. 이를 통해 Home Assistant와 연동하여 **Niimbot** 라벨 프린터 및 **Gicisky** BLE 전자종이(E-Paper) 라벨에 자동으로 정보를 출력할 수 있습니다.

### 1. Stash 설정

1. Stash 웹 UI 진입 후 **더보기(More)** → **외부 연동 관리(Integrations)**로 이동합니다.
2. **`INVENTORY_WEBHOOK_URL`** 항목에 Home Assistant의 Webhook URL을 입력하고 저장합니다.
   * 예: `http://<HA_IP>:8123/api/webhook/stash_print_webhook`

### 2. Home Assistant 자동화 구성

Stash에서 인쇄 요청(`item.print_requested` 이벤트)을 보내면 Webhook을 통해 Home Assistant가 페이로드를 수신합니다. 수신하는 데이터 구조는 다음과 같습니다:

```json
{
  "event": "item.print_requested",
  "itemId": "clx...",
  "name": "아이템 이름",
  "quantity": 5,
  "unit": "개",
  "locationId": "loc...",
  "locationName": "냉장고",
  "barcodeValue": "8801234567890",
  "symbology": "EAN13",
  "labelImageUrl": "http://<STASH_IP>/api/items/clx.../label.png",
  "timestamp": "2026-07-17T13:45:00.000Z"
}
```

수신한 페이로드를 바탕으로 **[hass-niimbot](https://github.com/eigger/hass-niimbot)** 또는 **[hass-gicisky](https://github.com/eigger/hass-gicisky)** 서비스를 호출해 라벨을 인쇄합니다.

---

### Niimbot 라벨 프린터 연동 예시

Niimbot 서비스 `niimbot.print`와 [imagespec](https://github.com/eigger/imagespec) 레이아웃 엔진을 사용하여 인쇄합니다.

#### 방법 A: Stash가 생성한 이미지 그대로 인쇄 (`dlimg` 사용)
Stash에서 제공하는 `labelImageUrl`을 그대로 다운로드하여 출력하는 방식입니다.

```yaml
alias: Stash Niimbot 라벨 인쇄 (이미지)
description: Stash 웹훅을 수신하여 pre-rendered 라벨 이미지를 출력합니다.
trigger:
  - trigger: webhook
    webhook_id: stash_print_webhook
    allowed_methods:
      - POST
    local_only: true
condition:
  - condition: template
    value_template: "{{ trigger.json.event == 'item.print_requested' }}"
actions:
  - action: niimbot.print
    target:
      device_id: <YOUR_NIIMBOT_DEVICE_ID>
    data:
      payload:
        - type: dlimg
          x: 0
          "y": 0
          url: "{{ trigger.json.labelImageUrl }}"
          xsize: 400
          ysize: 240
          mode: stretch
          dither: true
      width: 400
      height: 240
      density: 3
mode: single
```

#### 방법 B: 데이터 기반 동적 레이아웃으로 인쇄
Webhook이 넘겨준 바코드 정보와 이름 등을 활용해 Home Assistant 단에서 직접 레이아웃을 정의하여 출력하는 방식입니다.

```yaml
alias: Stash Niimbot 라벨 인쇄 (동적 템플릿)
description: Stash 바코드/이름 정보를 가공하여 동적 레이아웃으로 출력합니다.
trigger:
  - trigger: webhook
    webhook_id: stash_print_webhook
    allowed_methods:
      - POST
    local_only: true
condition:
  - condition: template
    value_template: "{{ trigger.json.event == 'item.print_requested' }}"
actions:
  - action: niimbot.print
    target:
      device_id: <YOUR_NIIMBOT_DEVICE_ID>
    data:
      payload:
        - type: qrcode
          data: "{{ trigger.json.barcodeValue }}"
          x: 120
          "y": 20
          boxsize: 4
        - type: text
          value: "{{ trigger.json.name }}"
          x: 40
          "y": 160
          size: 30
        - type: text
          value: "위치: {{ trigger.json.locationName | default('미지정') }}"
          x: 40
          "y": 200
          size: 20
      width: 400
      height: 240
      density: 3
mode: single
```

---

### Gicisky E-Paper 전자 라벨 연동 예시

Gicisky 서비스 `gicisky.write` (또는 `gicisky.write_guarded`)를 사용하여 BLE로 전자 라벨 정보를 업데이트합니다. E-Paper 패널 크기에 맞춰 레이아웃을 작성합니다.

#### 방법 A: Stash 라벨 이미지를 그대로 전송
```yaml
alias: Stash Gicisky 라벨 전송 (이미지)
description: Stash 웹훅을 수신하여 Gicisky E-Paper에 이미지를 그립니다.
trigger:
  - trigger: webhook
    webhook_id: stash_print_webhook
    allowed_methods:
      - POST
    local_only: true
condition:
  - condition: template
    value_template: "{{ trigger.json.event == 'item.print_requested' }}"
actions:
  - action: gicisky.write
    target:
      device_id: <YOUR_GICISKY_DEVICE_ID>
    data:
      payload:
        - type: dlimg
          x: 0
          "y": 0
          url: "{{ trigger.json.labelImageUrl }}"
          xsize: 296
          ysize: 128
          mode: stretch
          dither: true
mode: single
```

#### 방법 B: E-Paper 특성을 고려한 3색(BWR) 동적 레이아웃
이름은 검정색, 바코드는 QR, 수량/위치는 빨간색 등으로 구분하여 시각성을 높입니다.

```yaml
alias: Stash Gicisky 라벨 전송 (동적 템플릿)
description: Gicisky E-Paper 맞춤형 레이아웃을 구성하여 화면을 갱신합니다.
trigger:
  - trigger: webhook
    webhook_id: stash_print_webhook
    allowed_methods:
      - POST
    local_only: true
condition:
  - condition: template
    value_template: "{{ trigger.json.event == 'item.print_requested' }}"
actions:
  - action: gicisky.write
    target:
      device_id: <YOUR_GICISKY_DEVICE_ID>
    data:
      payload:
        # 아이템 이름 (검정)
        - type: text
          value: "{{ trigger.json.name }}"
          x: 10
          "y": 15
          size: 24
          color: black
        # 수량 정보 (빨강 강조)
        - type: text
          value: "재고: {{ trigger.json.quantity }} {{ trigger.json.unit | default('개') }}"
          x: 10
          "y": 50
          size: 18
          color: red
        # 보관 위치 (검정)
        - type: text
          value: "위치: {{ trigger.json.locationName | default('-') }}"
          x: 10
          "y": 80
          size: 16
          color: black
        # 우측 QR 코드
        - type: qrcode
          data: "{{ trigger.json.barcodeValue }}"
          x: 180
          "y": 14
          boxsize: 4
mode: single
```

## 폴더 구조

```
stash/
└── README.md
```

## 비밀값

Webhook URL 및 API 키 등은 외부로 노출되지 않도록 주의하십시오.
