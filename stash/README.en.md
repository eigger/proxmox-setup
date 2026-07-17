# Stash

**Language:** [한국어](README.md) · [English](README.en.md)

[Stash](https://github.com/eigger/stash) — self-hosted home inventory & barcode manager. Track and restock items with barcode scanning (UPC/EAN, QR, or Matter pairing codes) and print labels.

## Installation

Proxmox VE **LXC** install script:

1. Run the command below on the Proxmox host **Shell**
2. Follow the wizard steps to create the LXC

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/eigger/stash/master/proxmox/ct/stash.sh)"
```

Web UI after installation: `http://<STASH_IP>` (default port **80**)

### Initial Setup

1. On first run, if the user table is empty, you will be redirected to the **Bootstrap Admin** page. Enter your name, email, and password to create the administrator account.
2. Go to the bottom navigation bar **More** → **Settings** to configure global settings (currency, default product lookup providers, etc.).

## Home Assistant Integration (Label Printing)

Stash supports an **Outbound Inventory Webhook** to dispatch events when inventory updates or a print is requested. You can integrate this with Home Assistant to automatically output barcode labels on **Niimbot** printers or **Gicisky** BLE E-Paper (electronic shelf label) tags.

### 1. Stash Configuration

1. In Stash, go to the bottom navigation **More** → **Integrations**.
2. Enter your Home Assistant Webhook URL under **`INVENTORY_WEBHOOK_URL`** and save.
   * Example: `http://<HA_IP>:8123/api/webhook/stash_print_webhook`

### 2. Home Assistant Automation

When you trigger a print from Stash, the webhook sends an HTTP POST request containing details about the item. The payload structure is as follows:

```json
{
  "event": "item.print_requested",
  "itemId": "clx...",
  "name": "Item Name",
  "quantity": 5,
  "unit": "pcs",
  "locationId": "loc...",
  "locationName": "Refrigerator",
  "barcodeValue": "8801234567890",
  "symbology": "EAN13",
  "labelImageUrl": "http://<STASH_IP>/api/items/clx.../label.png",
  "timestamp": "2026-07-17T13:45:00.000Z"
}
```

Use this payload to call services in the **[hass-niimbot](https://github.com/eigger/hass-niimbot)** or **[hass-gicisky](https://github.com/eigger/hass-gicisky)** integrations.

---

### Niimbot Label Printer Integration Example

Utilizes the `niimbot.print` service with the [imagespec](https://github.com/eigger/imagespec) layout engine.

#### Option A: Print the pre-rendered Stash image (`dlimg` element)
Downloads the generated PNG label from Stash and sends it directly to the printer.

```yaml
alias: Stash Niimbot Print Label (Image)
description: Receives Stash webhook to print pre-rendered label image.
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

#### Option B: Dynamic layout using template fields
Defines a custom layout inside Home Assistant using barcode, text, and variables.

```yaml
alias: Stash Niimbot Print Label (Dynamic Template)
description: Formats barcode and item name dynamically to print.
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
          value: "Location: {{ trigger.json.locationName | default('None') }}"
          x: 40
          "y": 200
          size: 20
      width: 400
      height: 240
      density: 3
mode: single
```

---

### Gicisky E-Paper Label Integration Example

Utilizes the `gicisky.write` (or `gicisky.write_guarded`) service to update the E-Paper panel over BLE.

#### Option A: Draw the pre-rendered Stash image
```yaml
alias: Stash Gicisky ESL Draw (Image)
description: Receives Stash webhook to render label image on E-Paper.
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

#### Option B: 3-Color (BWR) E-Paper dynamic layout
Draws text, stock levels, location, and a QR barcode with black and red colors for high readability.

```yaml
alias: Stash Gicisky ESL Draw (Dynamic Template)
description: Displays item name, stock, location and QR on Gicisky tag.
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
        # Item name (Black)
        - type: text
          value: "{{ trigger.json.name }}"
          x: 10
          "y": 15
          size: 24
          color: black
        # Quantity / Unit (Red highlight)
        - type: text
          value: "Stock: {{ trigger.json.quantity }} {{ trigger.json.unit | default('pcs') }}"
          x: 10
          "y": 50
          size: 18
          color: red
        # Location (Black)
        - type: text
          value: "Loc: {{ trigger.json.locationName | default('-') }}"
          x: 10
          "y": 80
          size: 16
          color: black
        # QR Code on the right
        - type: qrcode
          data: "{{ trigger.json.barcodeValue }}"
          x: 180
          "y": 14
          boxsize: 4
mode: single
```

## Folder Structure

```
stash/
└── README.en.md
```

## Secrets

Take precautions not to expose your Home Assistant Webhook ID or public API URLs in commit history.
