# packages/http.yaml

[Cloudflare Tunnel](../../cloudflared/tunnel-setup.md) 등 프록시 뒤에서 Home Assistant가 **클라이언트 IP·스킴(HTTPS)** 를 올바르게 인식하도록 `http` 통합을 설정합니다.

HA 경로: `/config/packages/http.yaml`

## 사전 조건

- [cloudflared LXC](../../cloudflared/README.md) 설치·터널 구성 완료
- `<CLOUDFLARED_LXC_IP>` — cloudflared LXC LAN IP

## 내용

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 172.30.33.0/24
    - <CLOUDFLARED_LXC_IP>
```

| 항목 | 설명 |
|------|------|
| `use_x_forwarded_for` | `X-Forwarded-For` 헤더로 실제 클라이언트 IP 사용 |
| `172.30.33.0/24` | HA OS **내부(슈퍼바이저/애드온)** 대역 |
| `<CLOUDFLARED_LXC_IP>` | cloudflared LXC LAN IP (단일 IP, `/24` 없이) |

NPM 등 **다른 리버스 프록시** IP가 있으면 `trusted_proxies` 목록에 추가합니다.

## 연동

| 문서 | 내용 |
|------|------|
| [cloudflared/tunnel-setup.md](../../cloudflared/tunnel-setup.md#5-home-assistant--trusted_proxies) | Tunnel + HA 절차 |
| [config-structure.md](../config-structure.md) | packages·secrets 구조 |

## 적용

1. `packages/http.yaml` 배치 후 `<CLOUDFLARED_LXC_IP>` 수정
2. **개발자 도구 → YAML** 구성 확인
3. 필요 시 HA 재시작
