# packages/tasmota.yaml

**Language:** [한국어](tasmota.md) · [English](tasmota.en.md)

Reports IR codes received by the [Athom Tasmota IR Remote](https://www.athom.tech/) (AR01) as MQTT sensors and controls IR devices such as fans from HA.

HA path: `/config/packages/tasmota.yaml`

## Prerequisites

1. Configure HA **MQTT** integration (Mosquitto add-on or external broker)
2. Tasmota **Topic** = `tasmota_ir` (Console → `Topic tasmota_ir` or Web UI)
3. Tasmota IR receive log: `SetOption60 1` (JSON `IrReceived` on `tele/.../RESULT`)

If the topic prefix differs, replace all `tasmota_ir` in the YAML with the actual Topic.

## MQTT topics

| Topic | Purpose |
|------|------|
| `tele/tasmota_ir/LWT` | Online status |
| `tele/tasmota_ir/RESULT` | IR receive (`IrReceived`) |
| `cmnd/tasmota_ir/irsend` | IR transmit |

## Active entities

| Device | Entity | Description |
|------|--------|------|
| Athom IR | `sensor.tasmota_ir_controller_irreceived` | Received IR `Data` |
| Balmuda GreenFan S | `button.greenfans_*` ×4 | OnOff, Rotate, Speed, Timer |
| Hanil BBF-BL12W | `button.hanil_fan_*` ×8 | OnOff, Mode, Speed±, Rotate, Timer±, Mute |

IR code learning: send a signal from the remote, then check Protocol·Data in `sensor..._irreceived` attributes.

## Apply

1. Verify MQTT integration and Tasmota Topic
2. Deploy `packages/tasmota.yaml`
3. **Developer tools → YAML** — check configuration
4. Add `button`·`sensor` to dashboard
