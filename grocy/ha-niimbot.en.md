# Home Assistant ↔ grocy (Niimbot labels)

**Language:** [한국어](ha-niimbot.md) · [English](ha-niimbot.en.md)

Send print requests from the grocy **label printer Webhook** and output QR codes and product names on a Niimbot label printer via Home Assistant **[hass-niimbot](https://github.com/eigger/hass-niimbot)**.

LXC install: [README.en.md](README.en.md) · no combined `homeassistant/packages/` bundle (automation is in this doc §2)

Original example: [hass-niimbot/examples/grocy](https://github.com/eigger/hass-niimbot/tree/master/examples/grocy)

```
grocy (label print) ──POST──► HA Webhook ──► niimbot.print ──► Niimbot
```

## Environment (placeholders)

| Item | Example | Description |
|------|------|------|
| Home Assistant | `<HA_IP>` | HA LAN address (port 8123) |
| Webhook ID | `<WEBHOOK_ID>` | Issued by HA automation (last URL path segment) |
| Niimbot | `<NIIMBOT_DEVICE_ID>` | Niimbot `device_id` from HA **Settings → Devices** |

## 1. Prerequisites

1. Install [hass-niimbot](https://github.com/eigger/hass-niimbot) in Home Assistant (HACS, etc.)
2. Register and connect the Niimbot printer in HA
3. Complete grocy LXC install — [README.en.md](README.en.md)

## 2. Home Assistant — Webhook automation

Create via **Settings → Automations** with a Webhook trigger, or add the YAML below to `automations.yaml`, packages, etc. Same layout as [hass-niimbot/examples/grocy](https://github.com/eigger/hass-niimbot/tree/master/examples/grocy).

`webhook_id` must match the **last segment** of `http://<HA_IP>:8123/api/webhook/<WEBHOOK_ID>`.

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

Example payload from grocy:

| Field | Purpose |
|------|------|
| `grocycode` | QR code data |
| `product` | Product name (label text) |

`local_only: true` — accept Webhook requests from LAN only (recommended).

## 3. grocy — config.php

community-scripts LXC config file: `/var/www/html/data/config.php`

Add the lines below or edit existing `Setting(...)` entries. Replace `<WEBHOOK_ID>` with the value from your Webhook automation.

```php
Setting('LABEL_PRINTER_WEBHOOK', 'http://<HA_IP>:8123/api/webhook/<WEBHOOK_ID>');
Setting('FEATURE_FLAG_LABEL_PRINTER', true);
```

After saving, **label printing** is enabled in grocy.

## 4. Verification

1. Print a product label from grocy
2. Check HA **Developer tools → Logs** / automation run history
3. Confirm QR + product name output on the Niimbot

Example screenshots: [hass-niimbot/examples/grocy](https://github.com/eigger/hass-niimbot/tree/master/examples/grocy) (`grocy.png`, `qrcode.jpg`)

## 5. Troubleshooting

| Symptom | Action |
|------|------|
| Print fails in grocy | Check `config.php` Webhook URL and `FEATURE_FLAG_LABEL_PRINTER` |
| HA Webhook not received | Match `webhook_id`, grocy → HA network/firewall; external URLs fail with `local_only` |
| Niimbot no output | Check `device_id`, printer connection, and `niimbot.print` service logs |
| QR/text position | Adjust `x`, `y`, `size`, `width`/`height` in `payload` |

## 6. Security

- Webhook URL and `webhook_id` **allow anyone to trigger printing if leaked** — keep `local_only: true`
- Do **not** commit real IDs/IPs in `config.php` or HA automation YAML to git
