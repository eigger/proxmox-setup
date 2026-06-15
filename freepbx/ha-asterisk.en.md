# Home Assistant ↔ FreePBX (AMI)

**Language:** [한국어](ha-asterisk.md) · [English](ha-asterisk.en.md)

> [!NOTE]
> This configuration is now **optional (nice-to-have)** and no longer mandatory.
> It is recommended to use [ha-hass-sip.en.md (SIP Client HACS Integration)](ha-hass-sip.en.md) as the primary integration method, which operates as a native media player entity.

Grandstream analog extensions register **only with FreePBX (SIP)**; Home Assistant controls the PBX via **AMI (5038)**. The HA Asterisk **add-on is not required**.

LXC install and ports: [README.en.md](README.en.md) · No combined package in `homeassistant/packages/` (add-on and automation details are in this document)

For **Edge TTS and webhook inbound calls** over SIP on HA, see [ha-sip.en.md](ha-sip.en.md) (arnonym **ha-sip** add-on) as well.

## Environment (placeholders)

| Item | Example | Description |
|------|------|------|
| Home Assistant | `<HA_IP>` | AMI client LAN address |
| FreePBX | `<FREEPBX_IP>` | PBX, AMI, PJSIP |
| Grandstream | `<TARGET_EXT>` | ATA extension number |

```
HA ──AMI 5038──► FreePBX ──SIP 5060──► Grandstream (analog phone)
```

## SIP registration vs AMI (common confusion)

| | Grandstream | Home Assistant |
|--|-------------|----------------|
| Protocol | SIP | AMI (Manager) |
| Port | 5060 | 5038 |
| Account | Extension + **Secret** | **Asterisk Manager User** + Secret |
| GUI indicator | PJSIP **Registered** | Asterisk **integration** connected |

Even if an extension shows Registered, HA will not connect without **`bindaddr` and a Manager User**.



## 1. FreePBX — Asterisk Manager User

**Settings → Advanced Settings → Asterisk Manager Users**

| Field | Value (example) |
|------|-----------|
| Name | `Homeassistant` (**same** as HA Username, case-sensitive) |
| Secret | AMI-only password (**not** the FreePBX web login password) |
| Deny | `0.0.0.0/0.0.0.0` |
| Permit | `127.0.0.1/255.255.255.255` |
| | `<HA_IP>/255.255.255.255` |
| Write Timeout | `5000` |

Include **`originate`** in Read/Write (add report etc. if needed).

**Submit** → **Apply Config**

Other accounts (`cdrpro_events`, `srtapi_*`, etc.) are **internal** with `127.0.0.1` only — no changes needed.



## 2. FreePBX — AMI Bind Address (required)

FreePBX 16+ default: **Bind Address `127.0.0.1`** → `5038` from LAN returns **Connection refused**.

Example notice on the Asterisk Manager Users page:

> AMI current settings for Bind Address : 127.0.0.1 and bind port : 5038

### GUI Config Edit will not work

FreePBX **auto-generates** `manager.conf` → **File is not writable** in Config Edit is expected.

### Edit via CLI

```bash
nano /etc/asterisk/manager.conf
```

In `[general]`:

```ini
bindaddr = 0.0.0.0
port = 5038
```

Keep includes at the bottom of the file:

```ini
#include manager_additional.conf
#include manager_custom.conf
```

Apply:

```bash
fwconsole reload
asterisk -rx "manager show settings"
```

Confirm `TCP Bindaddress: 0.0.0.0:5038`.

Reference: [FreePBX 16 AMI default configuration](https://sangomakb.atlassian.net/wiki/spaces/PG/pages/26706045/PBX+GUI+-+AMI+Default+Configuration+in+16)

> If GUI **Apply Config** resets `bindaddr` to `127.0.0.1`, edit again. If it repeats, consider `chattr +i /etc/asterisk/manager.conf` (run `chattr -i` before updates).



## 3. Connection verification

### Mac / HA host

```bash
nc -zv <FREEPBX_IP> 5038
```

Should show `succeeded` / `open`.

### AMI login

```bash
(
  printf 'Action: Login\r\nUsername: Homeassistant\r\nSecret: <AMI_SECRET>\r\n\r\n'
  sleep 2
) | nc <FREEPBX_IP> 5038
```

Confirm `Authentication accepted`.



## 4. Home Assistant — Asterisk integration

Install [HACS: asterisk-hass-integration](https://github.com/TECH7Fox/asterisk-hass-integration), then **Settings → Integrations → Asterisk**.

| Item | Value |
|------|-----|
| Host | `<FREEPBX_IP>` |
| Port | `5038` |
| Username | `Homeassistant` |
| Password | Manager **Secret** |

Documentation: [Send Action Service](https://tech7fox.github.io/sip-hass-docs/docs/integration/services/send_action)

On success, PJSIP extensions appear as HA **devices**.



## 5. `asterisk.send_action` — call extension and play audio

Service: **`asterisk.send_action`** — passes AMI `Originate` and similar actions.

> `timeout` is in **milliseconds** (e.g. 60 seconds = `60000`).

### Developer tools (Playback)

Assumes audio exists on FreePBX at `/var/lib/asterisk/sounds/custom/ha-alert.wav` (use `custom/ha-alert` without extension).

```yaml
action: Originate
parameters:
  channel: PJSIP/1001
  application: Playback
  data: custom/ha-alert
  callerid: "Home Assistant"
  timeout: 60000
```

### Using a dialplan context

After defining `[ha-tts]` in `extensions_custom.conf`:

```yaml
action: Originate
parameters:
  channel: PJSIP/1001
  context: ha-tts
  exten: s
  priority: "1"
  callerid: "Home Assistant"
  timeout: 60000
```

### Automation example

```yaml
automation:
  - alias: "집 전화 알림"
    triggers:
      - platform: state
        entity_id: binary_sensor.example
        to: "on"
    actions:
      - action: asterisk.send_action
        data:
          action: Originate
          parameters:
            channel: PJSIP/1001
            application: Playback
            data: custom/ha-alert
            callerid: "Home Assistant"
            timeout: 60000
```

### FreePBX CLI test (without HA)

```bash
asterisk -rx "channel originate PJSIP/1001 application Playback custom/ha-alert"
```



## 6. TTS integration (next steps)

1. Generate sentence → wav with HA `tts.speak`, etc.  
2. Copy to `/var/lib/asterisk/sounds/custom/` in Asterisk-compatible format (8 kHz mono, etc.) via scp/SSH  
3. `asterisk.send_action` → `Playback` `custom/filename`

Dynamic sentences and Polly modules can be extended via FreePBX AGI/modules.

### `ha-tts` dialplan example

**Admin → Config Edit** or `/etc/asterisk/extensions_custom.conf`:

```ini
[ha-tts]
exten => s,1,NoOp(HA TTS)
 same => n,Answer()
 same => n,Wait(1)
 same => n,Playback(custom/ha-alert)
 same => n,Hangup()
```

After **Apply Config**, run `asterisk -rx "dialplan show ha-tts"`.



## 7. Troubleshooting

| Symptom | Cause | Action |
|------|------|------|
| `nc` Connection refused | `bindaddr = 127.0.0.1` | Set `0.0.0.0` + reload |
| HA Cannot connect to AMI | Above + wrong Password | Manager Secret, Host IP |
| Authentication failed | Web admin password / extension Secret used | AMI Secret only |
| failed to pass IP ACL | HA IP not in Permit | Add `<HA_IP>/255.255.255.255` |
| Call ends immediately | timeout too short | Use `60000`, etc. |
| Grandstream OK, HA fails | SIP ≠ AMI | Section 2 of this document |



## 8. Security

- With `bindaddr = 0.0.0.0`, restrict by **Manager User Permit** IP (`Homeassistant` → HA only).
- Do not commit AMI Secret or Extension Secret to the repository.
- Do **not** forward port 5038 on the router (LAN only).
