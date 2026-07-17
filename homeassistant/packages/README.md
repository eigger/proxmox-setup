# packages/

**Language:** [한국어](README.md) · [English](README.en.md)

Home Assistant `configuration.yaml`의 `!include_dir_named packages` 대상입니다.

HA 인스턴스 경로: `/config/packages/`

**YAML은 이 폴더가 단일 출처**입니다. 자동화·시나리오 설명은 각 서비스 폴더의 `ha-*.md`를 따릅니다.

| packages | 내용 | 연동 가이드 |
|----------|------|-------------|
| [http.yaml](http.yaml) | `trusted_proxies` | [cloudflared/tunnel-setup.md](../../cloudflared/tunnel-setup.md#5-home-assistant--trusted_proxies) · [http.md](http.md) |
| [garage.yaml](garage.yaml) | Garage `rest_command` 및 센서 | [garage/README.md](../../garage/README.md) |
| [tasmota.yaml](tasmota.yaml) | Athom IR Remote MQTT | [tasmota.md](tasmota.md) |
| [tmap.yaml](tmap.yaml) | SK TMAP 경로안내 | [tmap.md](tmap.md) |
| [wol.yaml](wol.yaml) | NAS Wake-on-LAN | [wol.md](wol.md) |
| [recorder.yaml](recorder.yaml) | Recorder 7일 보관·외부 DB | [recorder.md](recorder.md) |
| [lubelogger.yaml (미사용)](lubelogger.yaml) | LubeLogger `rest_command` | [lubelogger/ha-rest-command.md](../../lubelogger/ha-rest-command.md) · [lubelogger.md](lubelogger.md) · 주유: [hass-opinet](https://github.com/eigger/hass-opinet) · [ha-fuel-opinet.md](../../lubelogger/ha-fuel-opinet.md) |
| [traccar.yaml (미사용)](traccar.yaml) | Traccar `send_to_traccar` | [traccar/ha-rest-command.md](../../traccar/ha-rest-command.md) · [traccar.md](traccar.md) |
구조·secrets: [config-structure.md](../config-structure.md)
