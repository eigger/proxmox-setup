# packages/wol.yaml

**Language:** [한국어](wol.md) · [English](wol.en.md)

Remotely powers on devices such as a NAS with a [Wake-on-LAN](https://www.home-assistant.io/integrations/wake_on_lan/) magic packet.

HA path: `/config/packages/wol.yaml`

## Prerequisites

- **Wake-on-LAN** enabled in target device BIOS/firmware
- HA and NAS on the same LAN (or a network where broadcast can reach the target)

## Configuration

Replace `<NAS_MAC>` in `wol.yaml` with the target device MAC.

```yaml
switch:
  - platform: wake_on_lan
    name: NAS Wake on lan
    mac: "<NAS_MAC>"
```

| Item | Description |
|------|------|
| `name` | HA UI display name → entity_id example: `switch.nas_wake_on_lan` |
| `mac` | WoL target MAC (`XX:XX:XX:XX:XX:XX`) |

If subnet broadcast is required, add `broadcast_address`·`broadcast_port` per the [official docs](https://www.home-assistant.io/integrations/wake_on_lan/).

## Usage

- Turn **NAS Wake on lan** switch ON from the dashboard
- Automation: `service: switch.turn_on` · `entity_id: switch.nas_wake_on_lan`

## Apply

1. Deploy `packages/wol.yaml` and set MAC
2. **Developer tools → YAML** — check configuration
