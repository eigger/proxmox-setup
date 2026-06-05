# proxmox-setup

Proxmox 위 VM/LXC별 **설치·운영 설정**을 서버(역할)마다 디렉터리로 정리합니다.

| 서버 / 주제 | 경로 | 설명 |
|-------------|------|------|
| Proxmox 호스트 | [proxmox/](proxmox/) | 호스트 백업·연동 (Google Drive 등) |
| Home Assistant OS | [homeassistant/](homeassistant/) | HA OS VM, [packages](homeassistant/config-structure.md) 구조 |
| FreePBX | [freepbx/](freepbx/) | IP-PBX (Asterisk + FreePBX 웹 UI) |
| LubeLogger | [lubelogger/](lubelogger/) | 차량 정비·연비 트래커 (한국어 번역, HA 연동) |
| Traccar | [traccar/](traccar/) | GPS 추적 서버 (HA REST Command) |
| grocy | [grocy/](grocy/) | 식료품·가사 재고 관리 (Niimbot 라벨 연동) |
| Cloudflared | [cloudflared/](cloudflared/) | Cloudflare Tunnel (LXC, [터널 구성](cloudflared/tunnel-setup.md)) |
| Cloudflare DDNS | [cloudflare-ddns/](cloudflare-ddns/) | 동적 DNS 갱신 (LXC) |

각 디렉터리의 `README.md`가 **LXC/VM 설치·운영**의 입구입니다. Home Assistant 연동은 아래처럼 나눕니다.

| 층 | 위치 | 내용 |
|----|------|------|
| LXC README | `lubelogger/README.md` 등 | 설치, 포트, HA 연동 **링크만** |
| 연동 상세 | `*/ha-*.md` | API·자동화·Webhook·시나리오 |
| HA packages | [homeassistant/packages/](homeassistant/packages/) | `/config/packages/`에 넣을 YAML |

전체 구조: [homeassistant/config-structure.md](homeassistant/config-structure.md)
