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

Documentation: [ha-plugins README](https://github.com/arnonym/ha-plugins/blob/main/README.md)

## 3. ha-sip add-on configuration (YAML)

Replace `<FREEPBX_IP>`, `<HA_SIP_EXT>`, and `<FREEPBX_EXTENSION_SECRET>` with actual values.

```yaml
sip_global:
  port: 5060
  log_level: 5
  name_server: ""
  cache_dir: "/config/audio_cache"
  global_options: ""

sip:
  enabled: true
  registrar_uri: "sip:<FREEPBX_IP>"
  id_uri: "sip:<HA_SIP_EXT>@<FREEPBX_IP>"
  realm: "*"
  user_name: "<HA_SIP_EXT>"
  password: "<FREEPBX_EXTENSION_SECRET>"
  answer_mode: listen
  settle_time: 1
  incoming_call_file: ""
  options: ""

sip_2:
  enabled: false

tts:
  engine_id: "tts.edge_tts"
  platform: ""
  language: "ko-KR"
  voice: "ko-KR-SunHiNeural"
  debug_print: false

webhook:
  id: "<WEBHOOK_ID>"
```

### TTS fields

| Field | Value | Notes |
|------|-----|------|
| `engine_id` | `tts.edge_tts` | Edge TTS entity ID installed in HA (check the state screen if different) |
| `platform` | `""` | **Leave empty when using `engine_id`** |
| `language` | `ko-KR` | |
| `voice` | `ko-KR-SunHiNeural` | Other Neural voices are supported |
| `debug_print` | `true` → verify, then `false` | Logs engine and language list on startup |

If using voice ID only, try `language: "ko-KR-SunHiNeural"`, `voice: ""`.

### `answer_mode`

| Value | Behavior |
|----|------|
| `listen` | On incoming call, **webhook only** (does not answer) → HA automation |
| `accept` | **Auto-answer** via `incoming_call_file` menu, PIN, DTMF |

Incoming menu example: `/config/sip-incoming.yaml` — [README Incoming calls](https://github.com/arnonym/ha-plugins#incoming-calls)

## 4. Outbound — call another extension + TTS

Use the slug from **Settings → Add-ons → ha-sip → Info** in `addon:` (varies per install, e.g. `c7744bff_ha-sip`).

Automation **YAML mode**:

```yaml
service: hassio.addon_stdin
data:
  addon: <HA_SIP_ADDON_SLUG>
  input:
    command: dial
    number: "sip:<TARGET_EXT>@<FREEPBX_IP>"
    sip_account: 1
    menu:
      message: "안내 메시지입니다."
      language: ko-KR-SunHiNeural
      post_action: hangup
```

TTS only during an active call:

```yaml
    command: play_message
    number: "sip:<TARGET_EXT>@<FREEPBX_IP>"
    message: "안내 메시지입니다."
    tts_language: ko-KR-SunHiNeural
    cache_audio: true
    wait_for_audio_to_finish: true
    post_action: hangup
```

## 5. Inbound — trigger HA automation from a call (summary)

1. Create **Automation → Trigger → Webhook** with the same ID as `webhook.id`
2. In `listen` mode: use `trigger.json.parsed_caller`, `trigger.json.event == "incoming_call"`, etc.
3. Answer and TTS: `command: answer`, `internal_id: "{{ trigger.json.internal_id }}"`

Details: [Web-hooks](https://github.com/arnonym/ha-plugins#web-hooks)

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
| Confused with AMI | 5038 Manager ≠ 5060 Extension — [ha-asterisk.en.md](ha-asterisk.en.md) |

## 8. Security

- Do **not commit** Extension Secret, webhook URL, or tokens
- With `accept` + PIN menu, restrict with `allowed_numbers`
- Do not forward SIP or AMI ports to the internet (LAN only)
