# Home Assistant OS

**Language:** [한국어](README.md) · [English](README.en.md)

[Home Assistant OS](https://www.home-assistant.io/installation/linux) — Proxmox **VM** 위에서 HA OS를 실행합니다. 설정은 **`packages/`** 로 기능별 분리합니다.

## 설치

Proxmox VE **VM** 설치 스크립트: [Home Assistant OS — Proxmox VE Helper Scripts](https://community-scripts.org/scripts/haos-vm)

공식 HA Team **qcow2** 이미지를 받아 VM을 생성합니다.

1. Proxmox 호스트 **Shell**에서 아래 명령 실행
2. 마법사 안내에 따라 스토리지·VM ID 등 선택

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/vm/haos-vm.sh)"
```

### 설치 후

- Proxmox에서 해당 **VM → Summary**(또는 Console) 탭에서 **VM IP** 확인
- 웹 UI: `http://<HA_IP>:8123` (기본 포트 **8123**)
- 초기 온보딩: 계정 생성·지역·통합 추가

### 참고 (스크립트 기본 프로필)

| 항목 | 기본값 |
|------|--------|
| vCPU | 2 |
| RAM | 4096 MB |
| 디스크 | **32 GB** (생성 시 최소 32GB, 크기 변경 불가) |

공식 문서: [home-assistant.io](https://www.home-assistant.io/docs/)

## 설정 구조

`configuration.yaml`은 packages 로드만 담당하고, 나머지는 `packages/`에 파일별로 둡니다.

```yaml
homeassistant:
  packages: !include_dir_named packages
```

문서 계층(LXC README → `ha-*.md` → packages YAML): [config-structure.md](config-structure.md)

### packages 목록

전체 표·연동 링크: [packages/README.md](packages/README.md)

| packages | 연동 상세 |
|----------|-----------|
| [http.yaml](packages/http.yaml) | [cloudflared/tunnel-setup.md](../cloudflared/tunnel-setup.md#5-home-assistant--trusted_proxies) |
| [hass-opinet](https://github.com/eigger/hass-opinet) | 오피넷 유가 (LubeLogger 주유) | [lubelogger/ha-fuel-opinet.md](../lubelogger/ha-fuel-opinet.md) |
| [lubelogger.yaml](packages/lubelogger.yaml) | [lubelogger/ha-rest-command.md](../lubelogger/ha-rest-command.md) |
| [traccar.yaml](packages/traccar.yaml) | [traccar/ha-rest-command.md](../traccar/ha-rest-command.md) |
| [tasmota.yaml](packages/tasmota.yaml) | [tasmota.md](packages/tasmota.md) |
| [tmap.yaml](packages/tmap.yaml) | [tmap.md](packages/tmap.md) |
| [wol.yaml](packages/wol.yaml) | [wol.md](packages/wol.md) |
| [recorder.yaml](packages/recorder.yaml) | [recorder.md](packages/recorder.md) |

HA 전용(LXC 폴더 없음): `tasmota`, `tmap`, `wol`, `recorder` — packages·`*.md`만 참고.

## LXC/VM 서비스 ↔ HA

각 서비스 **README**는 설치·포트만 담고, HA는 위 packages + 아래 `ha-*.md`로 연결합니다.

| 서비스 | LXC README | packages | 연동 상세 |
|--------|------------|----------|-----------|
| LubeLogger | [lubelogger/README.md](../lubelogger/README.md) | lubelogger, [hass-opinet](https://github.com/eigger/hass-opinet) | [ha-rest-command.md](../lubelogger/ha-rest-command.md), [ha-fuel-opinet.md](../lubelogger/ha-fuel-opinet.md) |
| Traccar | [traccar/README.md](../traccar/README.md) | traccar | [ha-rest-command.md](../traccar/ha-rest-command.md) |
| grocy | [grocy/README.md](../grocy/README.md) | — | [ha-niimbot.md](../grocy/ha-niimbot.md) |
| Cloudflared | [cloudflared/README.md](../cloudflared/README.md) | http | [tunnel-setup.md](../cloudflared/tunnel-setup.md) |
| FreePBX | [freepbx/README.md](../freepbx/README.md) | — | [ha-sip.md](../freepbx/ha-sip.md), [ha-asterisk.md](../freepbx/ha-asterisk.md) |

## 폴더 구조

```
homeassistant/
├── README.md
├── config-structure.md      # configuration.yaml + packages 개요
└── packages/                # *.yaml + *.md — 목록은 packages/README.md
```

## 비밀값

`secrets.yaml`, API 키, 토큰은 **커밋하지 않습니다**.
