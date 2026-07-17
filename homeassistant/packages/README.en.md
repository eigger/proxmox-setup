# packages/

**Language:** [한국어](README.md) · [English](README.en.md)

Target of `!include_dir_named packages` in Home Assistant `configuration.yaml`.

HA instance path: `/config/packages/`

**This folder is the single source for YAML.** Automation and scenario descriptions follow each service folder's `ha-*.md`.

| packages | Contents | Integration guide |
|----------|------|-------------|
| [http.yaml](http.yaml) | `trusted_proxies` | [cloudflared/tunnel-setup.en.md](../../cloudflared/tunnel-setup.en.md#5-home-assistant--trusted_proxies) · [http.en.md](http.en.md) |
| [garage.yaml](garage.yaml) | Garage `rest_command` & sensors | [garage/README.en.md](../../garage/README.en.md) |
| [tasmota.yaml](tasmota.yaml) | Athom IR Remote MQTT | [tasmota.en.md](tasmota.en.md) |
| [tmap.yaml](tmap.yaml) | SK TMAP route guidance | [tmap.en.md](tmap.en.md) |
| [wol.yaml](wol.yaml) | NAS Wake-on-LAN | [wol.en.md](wol.en.md) |
| [recorder.yaml](recorder.yaml) | Recorder 7-day retention·external DB | [recorder.en.md](recorder.en.md) |
| [lubelogger.yaml (unused)](lubelogger.yaml) | LubeLogger `rest_command` | [lubelogger/ha-rest-command.en.md](../../lubelogger/ha-rest-command.en.md) · [lubelogger.en.md](lubelogger.en.md) · fuel: [hass-opinet](https://github.com/eigger/hass-opinet) · [ha-fuel-opinet.en.md](../../lubelogger/ha-fuel-opinet.en.md) |
| [traccar.yaml (unused)](traccar.yaml) | Traccar `send_to_traccar` | [traccar/ha-rest-command.en.md](../../traccar/ha-rest-command.en.md) · [traccar.en.md](traccar.en.md) |

Structure·secrets: [config-structure.en.md](../config-structure.en.md)
