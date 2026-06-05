# Home Assistant ha-sip ↔ FreePBX

**Language:** [한국어](ha-sip.md) · [English](ha-sip.en.md)

The **ha-sip** add-on from [arnonym/ha-plugins](https://github.com/arnonym/ha-plugins) registers HA with FreePBX as a **SIP client**. TTS uses HA **Edge TTS** (`tts.edge_tts`).

LXC install and ports: [README.en.md](README.en.md) · No combined package in `homeassistant/packages/` (add-on config is in [3. ha-sip add-on configuration](#3-ha-sip-add-on-configuration-yaml))

### Note

Separate from the [TECH7Fox Asterisk add-on](https://github.com/TECH7Fox/asterisk-hass-addons) / [SIP-HASS](https://tech7fox.github.io/sip-hass-docs/) project.

## Difference from AMI integration

| | [ha-asterisk.en.md](ha-asterisk.en.md) (AMI) | ha-sip (this document) |
|--|--------------------------------------|------------------|
| Connection | TCP **5038** Manager | UDP/TCP **5060** SIP |
| FreePBX account | Asterisk Manager User | **PJSIP Extension** |
| HA role | Remote PBX control | **Registers like a phone** |
| TTS | PBX `Playback` / files | **HA Edge TTS** direct synthesis |
| Automation | `asterisk.send_action` | `hassio.addon_stdin` + Webhook |

Both can be used on FreePBX at the same time.

## Environment (placeholders)

| Item | Example | Description |
|------|------|------|
| FreePBX | `<FREEPBX_IP>` | PBX LAN address |
| ha-sip extension | `<HA_SIP_EXT>` | HA-only Extension (e.g. `100`) |
| Analog/other extension | `<TARGET_EXT>` | Grandstream etc. (e.g. `1001`) |

```
HA (ha-sip) ──SIP 5060──► FreePBX ──SIP──► Grandstream / other extensions
HA (AMI)    ──5038──────► FreePBX (automation Originate, separate doc)
```

## 1. FreePBX — ha-sip extension

1. **Applications → Extensions → Add PJSIP Extension**
2. **User Extension:** `<HA_SIP_EXT>` (a number **separate** from the Grandstream extension)
3. Record **Secret** → use only in ha-sip `password` (do not put in storage or git)
4. **Apply Config**
5. In **Reports → Asterisk Info → PJSIP**, confirm the extension shows **Registered** (after starting the ha-sip add-on)

## 2. HA — install add-on

1. **Settings → Add-ons → Add-on Store** → repository: `https://github.com/arnonym/ha-plugins`
2. Install **ha-sip**
3. Enter the configuration below, then **Start**
4. Check add-on **Logs** for a successful SIP registration message

Documentation: [ha-plugins README](https://github.com/arnonym/ha-plugins/blob/main/README.md) · Schema: [ha-sip/config.json](https://github.com/arnonym/ha-plugins/blob/main/ha-sip/config.json) (v5.5)

## 3. ha-sip add-on configuration (YAML)

Replace `<FREEPBX_IP>`, `<HA_SIP_EXT>`, and `<FREEPBX_EXTENSION_SECRET>` with actual values. Quote `user_name` / `password` if they start with a digit (e.g. `"100"`).

```yaml
sip_global:
  port: 5060
  log_level: 5
  name_server: ""
  cache_dir: /config/tts
  global_options: ""

sip:
  enabled: true
  registrar_uri: sip:<FREEPBX_IP>
  id_uri: sip:<HA_SIP_EXT>@<FREEPBX_IP>
  realm: "*"
  user_name: "<HA_SIP_EXT>"
  password: "<FREEPBX_EXTENSION_SECRET>"
  answer_mode: listen
  settle_time: 1
  incoming_call_file: ""
  options: ""

sip_2:
  enabled: false
  registrar_uri: sip:<OTHER_SIP_HOST>
  id_uri: sip:<OTHER_USER>@<OTHER_SIP_HOST>
  realm: "*"
  user_name: <OTHER_USER>
  password: <OTHER_SECRET>
  answer_mode: listen
  settle_time: 1
  incoming_call_file: ""
  options: ""

sip_3:
  enabled: false
  registrar_uri: sip:<OTHER_SIP_HOST>
  id_uri: ""
  realm: "*"
  user_name: ""
  password: ""
  answer_mode: listen
  settle_time: 1
  incoming_call_file: ""
  options: ""

tts:
  engine_id: tts.edge_tts_service_edge_tts
  platform: ""
  language: ko-KR
  voice: ko-KR-SunHiNeural
  debug_print: true

webhook:
  id: sip_call_webhook_id

sensors:
  enabled: false
  entity_prefix: ha_sip
```

Do **not** commit `password` or `webhook.id` to git. For FreePBX only, keep `sip` `enabled: true` and `sip_2` / `sip_3` `false`.

### Key fields

| Block | Field | Notes |
|------|------|------|
| `sip_global` | `cache_dir` | TTS cache directory. **Create under `/config` or `/media` before start** (otherwise log: `Cache directory not found`) |
| `sip` | `registrar_uri` / `id_uri` | FreePBX LAN IP and ha-sip extension |
| `sip` | `answer_mode: listen` | Incoming → webhook only ([§5](#5-inbound--trigger-ha-automation-from-a-call-summary)) |
| `tts` | `engine_id` | Check **Settings → Developer tools → States** for `tts.*` entity ID. e.g. `tts.edge_tts`, `tts.edge_tts_service_edge_tts` |
| `tts` | `platform` | `""` — **leave empty when using `engine_id`** |
| `tts` | `debug_print` | `true` to verify TTS, then `false` |
| `webhook` | `id` | Must **match** the HA automation Webhook trigger ID |
| `sensors` | `enabled` | SIP status sensors. `false` if not needed |

If using voice ID only, try `language: ko-KR-SunHiNeural`, `voice: ""`.

### `answer_mode`

| Value | Behavior |
|----|------|
| `listen` | On incoming call, **webhook only** (does not answer) → HA automation |
| `accept` | **Auto-answer** via `incoming_call_file` menu, PIN, DTMF |

Incoming menu example: `/config/sip-incoming.yaml` — [README Incoming calls](https://github.com/arnonym/ha-plugins#incoming-calls)

## 4. Outbound — call another extension + TTS

Outbound commands use `hassio.addon_stdin` ([command_handler.py](https://github.com/arnonym/ha-plugins/blob/main/ha-sip/src/command_handler.py)).

Use the slug from **Settings → Add-ons → ha-sip → Info** in `addon:` (varies per install, e.g. `ea162690_ha-sip`). Edit automations in **YAML mode**.

### `dial` — place call and play TTS

`command: dial` accepts: `number`, `menu`, `sip_account` (1–3), `ring_timeout` (seconds, default 300), optional `webhook_to_call`.

> Put **`post_action` and `wait_for_audio_to_finish` inside `menu`**, not at the top level of `input`. (`dial` only passes `menu` to the call handler.)

| `menu` field | Description |
|-------------|------|
| `message` | Text for TTS (no `tts` field) |
| `language` | (optional) Per-menu TTS language/voice; else [§3](#3-ha-sip-add-on-configuration-yaml) `tts.language` / `voice` |
| `post_action` | `hangup` · `noop` (default) · `repeat_message` · `return` · `jump <id>` |
| `wait_for_audio_to_finish` | `true` — ignore DTMF until playback ends |
| `cache_audio` | `true` — cache in `cache_dir` (static messages only) |

```yaml
action: hassio.addon_stdin
data:
  addon: <HA_SIP_ADDON_SLUG>
  input:
    command: dial
    number: sip:<TARGET_EXT>@<FREEPBX_IP>
    sip_account: 1
    ring_timeout: 15
    menu:
      message: "This is an announcement."
      post_action: hangup
      wait_for_audio_to_finish: true
```

`service: hassio.addon_stdin` works the same. A second `dial` to the **same number** while a call is active is **ignored**.

### `hangup`

```yaml
action: hassio.addon_stdin
data:
  addon: <HA_SIP_ADDON_SLUG>
  input:
    command: hangup
    number: sip:<TARGET_EXT>@<FREEPBX_IP>
```

### `play_message` — TTS on an established call

Only this command supports `wait_for_audio_to_finish` and `post_action` at the top level of `input`.

```yaml
action: hassio.addon_stdin
data:
  addon: <HA_SIP_ADDON_SLUG>
  input:
    command: play_message
    number: sip:<TARGET_EXT>@<FREEPBX_IP>
    message: "This is an announcement."
    tts_language: ko-KR
    cache_audio: false
    wait_for_audio_to_finish: true
    post_action: hangup
```

If `tts_language` is omitted, the add-on `tts.language` is used. DTMF, PIN, `choices`: [README Call menu](https://github.com/arnonym/ha-plugins#call-menu-definition).

## 5. Inbound — trigger HA automation from a call (summary)

With `answer_mode: listen`, calls are **not answered**; HA is triggered via `webhook.id`.

1. **Automation → Trigger → Webhook** with the same ID as `webhook.id`
2. Payload includes `event: incoming_call`, `parsed_caller`, `internal_id` ([README](https://github.com/arnonym/ha-plugins#listen-mode))
3. If using menu webhooks, filter with `trigger.json.event == "incoming_call"`

Answer and TTS (`number` must be **`internal_id`**, not `caller`):

```yaml
action: hassio.addon_stdin
data:
  addon: <HA_SIP_ADDON_SLUG>
  input:
    command: answer
    number: "{{ trigger.json.internal_id }}"
    menu:
      message: "This is an announcement."
      post_action: hangup
```

`accept` mode and PIN menus: `incoming_call_file` — [README Incoming calls](https://github.com/arnonym/ha-plugins#incoming-calls)

## 6. Connection verification

| Check | Method |
|------|------|
| SIP registration | FreePBX PJSIP shows `<HA_SIP_EXT>` Registered |
| TTS | Add-on logs after `debug_print: true` |
| Outbound | `dial` → `<TARGET_EXT>` rings |
| Firewall | HA → FreePBX **5060**, RTP (10000–20000) |

## 7. Troubleshooting

| Symptom | Action |
|------|------|
| Registration fails | Match Extension Secret, `<FREEPBX_IP>`, user_name; Apply Config |
| TTS fails | Verify `engine_id`, set `debug_print: true`, test `tts.speak` in HA |
| No call | Check `number` format `sip:<EXT>@<FREEPBX_IP>`, slug, `sip_account: 1` |
| Call does not hang up after TTS | Put `post_action: hangup` **inside `menu`** (top-level `dial` input is ignored) |
| TTS cache error | **Create** `cache_dir` under HA `/config` first |
| Confused with AMI | 5038 Manager ≠ 5060 Extension — [ha-asterisk.en.md](ha-asterisk.en.md) |

## 8. Security

- Do **not commit** Extension Secret, webhook URL, or tokens
- With `accept` + PIN menu, restrict with `allowed_numbers`
- Do not forward SIP or AMI ports to the internet (LAN only)
