# Cloudflare DDNS

**Language:** [한국어](README.md) · [English](README.en.md)

[favonia/cloudflare-ddns](https://github.com/favonia/cloudflare-ddns) — 공인 IP 변경 시 Cloudflare DNS **A/AAAA** 레코드를 자동 갱신하는 경량 DDNS 업데이터.

## 설치

Proxmox VE **LXC** 설치 스크립트: [Cloudflare-DDNS — Proxmox VE Helper Scripts](https://community-scripts.org/scripts/cloudflare-ddns)

1. Proxmox 호스트 **Shell**에서 아래 명령 실행
2. 마법사에서 **Default** 또는 **Advanced** 선택 후 LXC 생성
3. 설치 중 **API 토큰·도메인·Proxied·IPv6** 입력 — [ddns-setup.md](ddns-setup.md)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/cloudflare-ddns.sh)"
```

설치 후: `systemctl status cloudflare-ddns` 로 서비스 상태 확인

## DDNS 설정

| 주제 | 문서 |
|------|------|
| API 토큰·도메인·서비스 수정 | [ddns-setup.md](ddns-setup.md) |

설정 파일: `/etc/systemd/system/cloudflare-ddns.service`  
upstream: [favonia/cloudflare-ddns](https://github.com/favonia/cloudflare-ddns)

## 폴더 구조

```
cloudflare-ddns/
├── README.md
└── ddns-setup.md            # Cloudflare API 토큰·DDNS 환경 변수
```

## 비밀값

`CLOUDFLARE_API_TOKEN`은 **커밋하지 않습니다**.
