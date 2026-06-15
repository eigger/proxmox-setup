# Home Assistant SIP Client (hass-sip) ↔ FreePBX

**Language:** [한국어](ha-hass-sip.md) · [English](ha-hass-sip.en.md)

This guide explains how to register Home Assistant (HA) directly to FreePBX as a **SIP Client** using the custom integration [eigger/hass-sip](https://github.com/eigger/hass-sip). Running natively inside HA as a `media_player` entity, it makes call control and TTS audio playback extremely simple. It also supports native control entities (switches/buttons), an event entity, Voice Assist bridging, contacts/caller ID mapping, intercom (auto-answer) mode, and Interactive Voice Response (IVR) phone menus.

LXC install and ports: [README.en.md](README.en.md) · No combined package in `homeassistant/packages/` (uses custom integration and services).

---

## Environment (Placeholders)

| Item | Example | Description |
|:---|:---|:---|
| FreePBX | `<FREEPBX_IP>` | PBX LAN Address |
| hass-sip extension | `<HA_SIP_EXT>` | HA-only SIP Extension (e.g., `100`) |
| Destination Extension | `<TARGET_EXT>` | Grandstream ATA or other softphones (e.g., `1001`) |

```
HA (hass-sip) ──SIP 5060──► FreePBX ──SIP 5060──► Grandstream ATA (Phone)
```

---

## 1. FreePBX — Create PJSIP Extension

1. Access FreePBX Web UI (`http://<FREEPBX_IP>`).
2. Go to **Applications → Extensions → Add Extension → Add New PJSIP Extension**.
3. Fill in the following details:
   - **User Extension:** `<HA_SIP_EXT>` (e.g., `100`)
   - **Display Name:** `Home Assistant`
   - **Secret:** Password (record this; you will need it for the HA integration setup).
4. Click **Submit**, then click the **Apply Config** button in the top right corner to apply changes.

---

## 2. Home Assistant — Install and Configure Integration

### HACS Installation
1. Go to the **HACS** menu in the HA Web UI.
2. Click the three dots in the top-right corner and select **Custom repositories**.
3. Add the following repository:
   - **Repository:** `https://github.com/eigger/hass-sip`
   - **Category:** `Integration`
4. Find and download the **SIP Client** integration.
5. **Restart** Home Assistant.

### Adding the Device (UI Config Flow)
1. Go to **Settings → Devices & Services → Add Integration**.
2. Search for and select **SIP Client**.
3. Complete the configuration form:
   - **Server / Host:** `<FREEPBX_IP>`
   - **Port:** `5060`
   - **Username:** `<HA_SIP_EXT>` (e.g., `100`)
   - **Password:** `<FREEPBX_EXTENSION_SECRET>`
   - **Domain (Optional):** Leave empty to default to Server IP.
   - **Caller ID (Optional):** `Home Assistant`
   - **RTP Port (Optional):** `7078`
4. Once registered, a new `media_player.sip_client` entity and several helper entities will be created automatically.

---

## 3. Control Entities (Switches & Buttons)

`hass-sip` creates native switches and buttons to make dashboard control and automated triggers easy.

### Switches
- **Do Not Disturb Switch** (`switch.sip_client_dnd`): Turn this ON to automatically reject all incoming calls with a `486 Busy Here` SIP response.
- **Auto-Answer Switch** (`switch.sip_client_auto_answer`): Turn this ON to globally auto-answer all incoming calls immediately.

### Buttons
- **Answer Button** (`button.sip_client_answer`): Press this button to answer an active incoming call.
- **Hang Up Button** (`button.sip_client_hangup`): Press this button to end the current call or decline an incoming call.

---

## 4. Services and Announcement Examples

Any standard Home Assistant TTS engine (e.g., Google Translate, Piper, Nabu Casa Cloud) can be used. Audio encoding and resampling (via ffmpeg) are handled automatically in the background.

### Option A: Simplified Parameters (Recommended - One-off Announcements)
By providing `message` and TTS configurations directly in the `sip.answer` or `sip.dial` service calls, the integration will automatically connect, speak the message, and hang up the call when playback finishes.

#### Answer Inbound Call, Speak, and Hang Up Automatically
```yaml
alias: "SIP: Auto-answer and speak on incoming call"
trigger:
  - platform: event
    event_type: sip_incoming_call
action:
  - service: sip.answer
    target:
      entity_id: media_player.sip_client
    data:
      message: "Hello, this is an automated announcement."
      tts_engine: tts.google_translate
      language: en
```

#### Place Outbound Call, Speak on Answer, and Hang Up Automatically
```yaml
alias: "SIP: Place outbound call and play TTS announcement"
action:
  - service: sip.dial
    target:
      entity_id: media_player.sip_client
    data:
      number: "sip:<TARGET_EXT>@<FREEPBX_IP>"
      ring_timeout: 30
      message: "A package has been delivered."
      tts_engine: tts.google_translate
      language: en
```

---

### Option B: Multi-step Automation (Advanced Flow Control)
For complex flows where you need precise control between answering, playing multiple audios, waiting for events, and hanging up.

```yaml
alias: "SIP: Advanced multi-step automation"
trigger:
  - platform: event
    event_type: sip_incoming_call
action:
  - service: sip.answer
    target:
      entity_id: media_player.sip_client
  # Wait until the call is fully established
  - wait_for_trigger:
      - platform: event
        event_type: sip_call_connected
    timeout: "00:00:10"
  # Speak message
  - service: tts.speak
    target:
      entity_id: tts.google_translate
    data:
      media_player_entity_id: media_player.sip_client
      message: "Hello, this is a multi-step notification message."
  # Wait for the audio transmission to finish to prevent truncation
  - wait_for_trigger:
      - platform: event
        event_type: sip_playback_done
    timeout: "00:00:30"
  # Hang up the call
  - service: sip.hangup
    target:
      entity_id: media_player.sip_client
```

#### Outbound Call, Play TTS upon Connection, and Hang Up (Multi-step)
```yaml
alias: "SIP: Dial, play TTS on connection, and hang up (Multi-step)"
action:
  - service: sip.dial
    target:
      entity_id: media_player.sip_client
    data:
      number: "sip:<TARGET_EXT>@<FREEPBX_IP>"
      ring_timeout: 30
  # Wait until the remote party answers
  - wait_for_trigger:
      - platform: event
        event_type: sip_call_connected
    timeout: "00:00:35"
  # Speak TTS message
  - service: tts.speak
    target:
      entity_id: tts.google_translate
    data:
      media_player_entity_id: media_player.sip_client
      message: "A package has been delivered to the parcel locker."
  # Wait for the playback to finish to avoid truncation
  - wait_for_trigger:
      - platform: event
        event_type: sip_playback_done
    timeout: "00:00:30"
  # Hang up the call
  - service: sip.hangup
    target:
      entity_id: media_player.sip_client
```

---

## 5. IVR Menu Engine Details (YAML Schema)

You can pass a YAML configuration schema to the `menu` field in the `sip.dial` or `sip.answer` service to build Interactive Voice Response menus.

### `tts` Configuration Block
Within the `tts` block of a menu or choice, specify the following parameters:
- `message` (or `text`): The text content to be spoken.
- `engine` (or `tts_engine`): The specific TTS engine entity ID (e.g. `tts.google_translate`, `tts.piper`).
- `language` (or `lang`): Language code (e.g. `en`, `ko`).
- `options` (or `tts_options`): Dictionary of voice-specific options.
- `handle_as_template`: Set to `true` to render the message as a Home Assistant Jinja template before speaking.

### IVR Menu Configuration Example
```yaml
service: sip.answer
target:
  entity_id: media_player.sip_client
data:
  menu:
    id: root
    tts:
      message: "Welcome to our Home. Press 1 to toggle the living room light. Press 2 to talk to our Voice Assistant."
      engine: tts.google_translate
      language: en
    wait_for_audio_to_finish: true
    timeout: 10
    choices_are_pin: false
    choices:
      "1":
        action:
          domain: light
          service: toggle
          entity_id: light.living_room_light
        tts:
          message: "Toggling the light now."
          engine: tts.google_translate
          language: en
        post_action: hangup
      "2":
        action:
          domain: assist_pipeline
        post_action: noop
      "default":
        tts:
          message: "Invalid selection."
          engine: tts.google_translate
          language: en
        post_action: repeat_message
      "timeout":
        post_action: hangup
```

---

## 6. Contacts & Caller ID Mapping

### `sip_contacts.json` Layout
You can map incoming caller numbers to friendly names. Create a file named `sip_contacts.json` in your Home Assistant configuration directory (e.g. `/config/` or `/homeassistant/`):

```json
{
  "1001": "Dad",
  "1002": "Mom",
  "1003": {
    "name": "Front Gate Intercom",
    "auto_answer": true
  }
}
```
* Mapped names are exposed via the `caller_name` attribute on the `sip_incoming_call` event and the last caller ID sensors.

### Intercom & Auto-Answer Mode
This integration can automatically answer incoming calls without ringing, which is useful for doorbell intercoms. It is triggered in three ways:
1. **Global Toggle**: The Auto-Answer switch entity (`switch.sip_client_auto_answer`) is turned ON.
2. **SIP Headers**: The incoming call includes standard headers like `Call-Info: ...; answer-after=0` or `Alert-Info: Ring Answer`.
3. **Contacts File**: The incoming caller ID matches an extension configured with `"auto_answer": true` in `sip_contacts.json`.

---

## 7. Dashboard and Advanced Automations

### Intercom Door Release Button Card (DTMF)
If you have a door entry intercom connected to the SIP line (e.g., at the front gate), you can create a Lovelace dashboard button to trigger the gate/door release mechanism by sending a specific DTMF digit (like `1` or `*`) to the active call.

```yaml
type: conditional
conditions:
  - condition: state
    entity: binary_sensor.sip_client_active
    state: "on"
card:
  type: button
  name: Open Door
  icon: mdi:door-open
  tap_action:
    action: call-service
    service: sip.send_dtmf
    target:
      entity_id: media_player.sip_client
    data:
      digits: "1" # Digit sequence your gate intercom expects
```

### Dashboard: Recent Calls List Card (Markdown Card)
You can display a dynamically updated call log of the last 20 calls using the `call_history` state attribute of the Last Call sensor (`sensor.sip_client_last_call`).

```yaml
type: markdown
title: "📞 Recent Calls"
content: >
  <table style="width: 100%; border-collapse: collapse;">
    <thead>
      <tr style="border-bottom: 2px solid var(--divider-color); text-align: left;">
        <th style="padding: 8px;">Time</th>
        <th style="padding: 8px;">Caller</th>
        <th style="padding: 8px;">Direction</th>
        <th style="padding: 8px; text-align: right;">Duration</th>
      </tr>
    </thead>
    <tbody>
      {% set history = state_attr('sensor.sip_client_last_call', 'call_history') %}
      {% if history %}
        {% for call in history %}
          <tr style="border-bottom: 1px solid var(--divider-color);">
            <td style="padding: 8px; font-size: 0.9em; color: var(--secondary-text-color);">
              {{ as_timestamp(call.timestamp) | timestamp_custom('%m/%d %H:%M') }}
            </td>
            <td style="padding: 8px;">
              <b>{{ call.name }}</b> <span style="font-size: 0.8em; color: var(--secondary-text-color);">({{ call.number }})</span>
            </td>
            <td style="padding: 8px; font-size: 0.9em;">
              {% if call.direction == 'incoming' %}
                {% if call.status == 'answered' %}
                  <span style="color: var(--success-color);">🟢 ↙️ Inbound</span>
                {% elif call.status == 'rejected' %}
                  <span style="color: var(--error-color);">🔴 🚫 Rejected</span>
                {% else %}
                  <span style="color: var(--warning-color);">🟠 ↙️ Missed</span>
                {% endif %}
              {% else %}
                {% if call.status == 'answered' %}
                  <span style="color: var(--info-color);">🔵 ↗️ Outbound</span>
                {% else %}
                  <span style="color: var(--secondary-text-color);">⚪ ↗️ Unanswered</span>
                {% endif %}
              {% endif %}
            </td>
            <td style="padding: 8px; text-align: right; font-size: 0.9em;">
              {% if call.duration > 0 %}
                {{ call.duration }}s
              {% else %}
                -
              {% endif %}
            </td>
          </tr>
        {% endfor %}
      {% else %}
        <tr>
          <td colspan="4" style="padding: 16px; text-align: center; color: var(--secondary-text-color);">
            No recent calls logged.
          </td>
        </tr>
      {% endif %}
    </tbody>
  </table>
```

### Voice Assist Automation Example
Bridge an incoming call directly to Home Assistant's Voice Assist pipeline.
```yaml
alias: "SIP: Bridge call to Voice Assist"
trigger:
  - platform: state
    entity_id: binary_sensor.sip_client_active
    to: "on"
action:
  - service: sip.answer
    target:
      entity_id: media_player.sip_client
  - service: sip.start_assist
    target:
      entity_id: media_player.sip_client
```

---

## 8. Events & Event Entity (HA Event Bus)

`hass-sip` fires raw events on the Home Assistant event bus and exposes a native **Event Entity** (`event.sip_client_call_events`) for easier UI-based automations.

### 1. Call Events Entity (Recommended for Automations)
Each SIP extension device includes a **Call Events** entity (e.g. `event.sip_client_call_events`).
You can use this entity as a trigger in the Home Assistant Automation Editor.

Supported event types (`event_type` attribute):
- `incoming`: Fired when an inbound call arrives. Attributes: `caller`, `caller_name`.
- `connected`: Fired when the call is answered.
- `playback_done`: Fired when TTS or audio playback finishes.
- `ended`: Fired when the call ends.
- `dtmf`: Fired when a DTMF key is pressed. Attributes: `digit`.
- `recording_started` / `recording_stopped`: Fired when call recording starts or stops.
- `registered`: Fired when the SIP client registers successfully.

### 2. Raw Event Bus Events

| Event Name | Payload (Extra Data) | Fired When |
|:---|:---|:---|
| `sip_registered` | None | Successfully registered with FreePBX |
| `sip_state_changed` | `state` (`idle`, `registering`, `registered`, `inviting`, `ringing_out`, `incoming`, `answering`, `in_call`) | The internal SIP state changes |
| `sip_incoming_call` | `caller`, `caller_name` | An inbound call arrives |
| `sip_call_connected` | None | Call becomes two-way established |
| `sip_playback_done` | None | Audio/TTS playback finishes transmitting |
| `sip_call_ended` | None | The call ends |
| `sip_dtmf_digit` | `digit` | A DTMF digit is received from remote party |
| `sip_recording_started` | `recording_file` | Local call recording starts |
| `sip_recording_stopped` | None | Local call recording stops |

---

## 9. Troubleshooting

- **Registration fails**: Double-check the extension credentials and the server IP. Verify that FreePBX Fail2Ban has not blocked the Home Assistant IP.
- **Audio cuts off / One-way audio**: Check UDP port routing. Ensure the local RTP port (`7078`) and FreePBX RTP port range (`10000-20000` UDP) are open and routed.
- **FFmpeg issues**: Verify that `ffmpeg` is installed and accessible on your Home Assistant host. It is required for real-time audio encoding.
