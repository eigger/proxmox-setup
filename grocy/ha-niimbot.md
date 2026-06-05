# Home Assistant ↔ grocy (Niimbot 라벨)

grocy **라벨 프린터 Webhook**으로 인쇄 요청을 보내고, Home Assistant **[hass-niimbot](https://github.com/eigger/hass-niimbot)** 연동으로 Niimbot 라벨기에 QR·상품명을 출력합니다.

LXC 설치: [README.md](README.md) · `homeassistant/packages/` 조합본 없음 (자동화는 이 문서 §2)

원본 예시: [hass-niimbot/examples/grocy](https://github.com/eigger/hass-niimbot/tree/master/examples/grocy)

```
grocy (라벨 인쇄) ──POST──► HA Webhook ──► niimbot.print ──► Niimbot
```

## 환경 (플레이스홀더)

| 항목 | 예시 | 설명 |
|------|------|------|
| Home Assistant | `<HA_IP>` | HA LAN 주소 (포트 8123) |
| Webhook ID | `<WEBHOOK_ID>` | HA 자동화에서 발급 (URL 마지막 경로) |
| Niimbot | `<NIIMBOT_DEVICE_ID>` | HA **설정 → 기기**에서 Niimbot `device_id` |

## 1. 사전 조건

1. Home Assistant에 [hass-niimbot](https://github.com/eigger/hass-niimbot) 설치 (HACS 등)
2. Niimbot 프린터를 HA에 등록·연결
3. grocy LXC 설치 완료 — [README.md](README.md)

## 2. Home Assistant — Webhook 자동화

**설정 → 자동화**에서 Webhook 트리거로 만들거나, 아래 YAML을 `automations.yaml`·packages 등에 넣습니다. [hass-niimbot/examples/grocy](https://github.com/eigger/hass-niimbot/tree/master/examples/grocy)와 동일한 구성입니다.

`webhook_id`는 URL `http://<HA_IP>:8123/api/webhook/<WEBHOOK_ID>`의 **마지막 세그먼트**와 일치해야 합니다.

```yaml
alias: grocy 라벨 인쇄
description: grocy Webhook 수신 시 Niimbot으로 상품 라벨을 인쇄합니다.
mode: single
triggers:
  - trigger: webhook
    webhook_id: "<WEBHOOK_ID>"
    allowed_methods:
      - POST
      - PUT
    local_only: true
actions:
  - action: niimbot.print
    target:
      device_id: "<NIIMBOT_DEVICE_ID>"
    data:
      width: 400
      height: 240
      density: 3
      payload:
        - type: qrcode
          data: "{{ trigger.json.grocycode }}"
          x: 120
          y: 30
          boxsize: 4
        - type: text
          value: "{{ trigger.json.product }}"
          x: 40
          y: 170
          size: 40
```

### Webhook JSON (grocy → HA)

grocy가 보내는 페이로드 예:

| 필드 | 용도 |
|------|------|
| `grocycode` | QR 코드 데이터 |
| `product` | 상품명 (라벨 텍스트) |

`local_only: true` — LAN 내부에서만 Webhook 수신 (권장).

## 3. grocy — config.php

community-scripts LXC 기준 설정 파일: `/var/www/html/data/config.php`

아래를 추가하거나 기존 `Setting(...)` 줄을 수정합니다. `<WEBHOOK_ID>`를 Webhook 자동화에서 기록한 값으로 바꿉니다.

```php
Setting('LABEL_PRINTER_WEBHOOK', 'http://<HA_IP>:8123/api/webhook/<WEBHOOK_ID>');
Setting('FEATURE_FLAG_LABEL_PRINTER', true);
```

저장 후 grocy에서 **라벨 인쇄** 기능이 활성화됩니다.

## 4. 동작 확인

1. grocy에서 상품 라벨 인쇄 실행
2. HA **개발자 도구 → 로그** / 자동화 실행 기록 확인
3. Niimbot에서 QR + 상품명 라벨 출력 확인

예시 화면: [hass-niimbot/examples/grocy](https://github.com/eigger/hass-niimbot/tree/master/examples/grocy) (`grocy.png`, `qrcode.jpg`)

## 5. 문제 해결

| 증상 | 조치 |
|------|------|
| grocy에서 인쇄 안 됨 | `config.php` Webhook URL·`FEATURE_FLAG_LABEL_PRINTER` 확인 |
| HA Webhook 미수신 | `webhook_id` 일치, grocy → HA 네트워크·방화벽, `local_only` 시 외부 URL 불가 |
| Niimbot 미출력 | `device_id`, 프린터 연결·`niimbot.print` 서비스 로그 확인 |
| QR/텍스트 위치 | `payload`의 `x`·`y`·`size`·`width`/`height` 조정 |

## 6. 보안

- Webhook URL·`webhook_id`는 **유출 시 누구나 인쇄 트리거 가능** — `local_only: true` 유지
- `config.php`·HA 자동화 YAML에 실제 ID/IP를 **git에 커밋하지 않음**
