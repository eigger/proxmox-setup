# packages/

**Language:** [한국어](README.md) · [English](README.en.md)

Target of `!include_dir_named packages` in Home Assistant `configuration.yaml`.

HA instance path: `/config/packages/`

**This folder is the single source for YAML.** Automation and scenario descriptions follow each service folder's `ha-*.md`.

| packages | Contents | Integration guide |
|----------|------|-------------|
| [http.yaml](http.yaml) | `trusted_proxies` | [cloudflared/tunnel-setup.en.md](../../cloudflared/tunnel-setup.en.md#5-home-assistant--trusted_proxies) · [http.en.md](http.en.md) |
| [opinet.yaml](opinet.yaml) | Opinet fuel station price REST | [lubelogger/ha-fuel-opinet.en.md](../../lubelogger/ha-fuel-opinet.en.md) · [opinet.en.md](opinet.en.md) |
| [lubelogger.yaml](lubelogger.yaml) | LubeLogger `rest_command` | [lubelogger/ha-rest-command.en.md](../../lubelogger/ha-rest-command.en.md) · [lubelogger.en.md](lubelogger.en.md) |
| [traccar.yaml](traccar.yaml) | Traccar `send_to_traccar` | [traccar/ha-rest-command.en.md](../../traccar/ha-rest-command.en.md) · [traccar.en.md](traccar.en.md) |
| [tasmota.yaml](tasmota.yaml) | Athom IR Remote MQTT | [tasmota.en.md](tasmota.en.md) |
| [tmap.yaml](tmap.yaml) | SK TMAP route guidance | [tmap.en.md](tmap.en.md) |
| [wol.yaml](wol.yaml) | NAS Wake-on-LAN | [wol.en.md](wol.en.md) |
| [recorder.yaml](recorder.yaml) | Recorder 7-day retention·external DB | [recorder.en.md](recorder.en.md) |

Structure·secrets: [config-structure.en.md](../config-structure.en.md)
