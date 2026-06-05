# Cloudflared

[Cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) — Cloudflare Tunnel 클라이언트. LAN 서비스를 포트포워딩 없이 Cloudflare 경유로 노출할 때 사용합니다.

## 설치

Proxmox VE **LXC** 설치 스크립트: [Cloudflared — Proxmox VE Helper Scripts](https://community-scripts.org/scripts/cloudflared)

1. Proxmox 호스트 **Shell**에서 아래 명령 실행
2. 마법사에서 **Default** 또는 **Advanced** 선택 후 LXC 생성

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/cloudflared.sh)"
```

설치 후: LXC **Summary**에서 LAN IP 확인 · 설정 파일 `/usr/local/etc/cloudflared/config.yml`

## 터널 구성

Cloudflare Zero Trust 대시보드에서 터널을 만들고, LXC에 토큰으로 서비스를 등록한 뒤 Public Hostname으로 내부 서비스를 연결합니다.

| 주제 | 문서 |
|------|------|
| 터널 개통·서브도메인 | [tunnel-setup.md](tunnel-setup.md) |

## Home Assistant 연동

HA를 터널 뒤에 둘 때 `trusted_proxies` 설정이 필요합니다.

| packages (`/config/packages/`) | 설명 |
|----------------------------------|------|
| [http.yaml](../homeassistant/packages/http.yaml) | `use_x_forwarded_for`, `trusted_proxies` |

| 연동 가이드 | 문서 |
|-------------|------|
| Tunnel + HA 설정 절차 | [tunnel-setup.md](tunnel-setup.md#5-home-assistant--trusted_proxies) |
| HA packages·secrets 구조 | [homeassistant/config-structure.md](../homeassistant/config-structure.md) |

공식 문서: [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)

## 폴더 구조

```
cloudflared/
├── README.md
└── tunnel-setup.md          # 터널 구성·HA trusted_proxies
```

HA packages: [http.yaml](../homeassistant/packages/http.yaml)

## 비밀값

터널 토큰·인증서·API 키는 **커밋하지 않습니다**.
