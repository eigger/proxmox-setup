# Cloudflare Tunnel 구성

**Language:** [한국어](tunnel-setup.md) · [English](tunnel-setup.en.md)

Cloudflare **도메인이 이미 연결된** 계정을 기준으로, Proxmox LXC의 `cloudflared`로 터널을 개통하고 내부 서비스를 서브도메인으로 노출하는 방법입니다.

기존 **Cloudflare DNS + NPM(Nginx Proxy Manager)** 조합 대신, 터널 **Public Hostname**으로 직접 연결하면 NPM 없이도 외부 접근을 구성할 수 있습니다.

```
인터넷 ──► Cloudflare ──► cloudflared LXC ──► LAN 서비스 (Proxmox, HA, …)
```

| 단계 | 문서 |
|------|------|
| LXC 설치 | [README.md](README.md#설치) |
| **터널 구성** | 이 문서 |

## 사전 조건

- Cloudflare에 **도메인** 등록·위임 완료
- Proxmox에 [cloudflared LXC](https://community-scripts.org/scripts/cloudflared) 설치 완료

## 1. Cloudflare에서 터널 생성

1. [Cloudflare Zero Trust](https://one.dash.cloudflare.com/) 접속  
   - 처음 사용 시 Zero Trust 구성·결제 정보 입력이 필요할 수 있음
2. **Networks → Tunnels → Create a tunnel**
3. Connector: **Cloudflared** 선택
4. 터널 **이름** 입력 (예: `homelab`, `proxmox-tunnel`)
5. 설치 안내 화면에서 **토큰**이 표시됨 — 다음 단계에서 사용 (`eyJhIjoi...` 형태). **복사해 두고 git·문서에 커밋하지 않음**

## 2. LXC에 cloudflared 서비스 등록

Proxmox에서 **cloudflared LXC → Console**에 접속해, 스크립트가 만든 기본 서비스를 제거한 뒤 **대시보드에서 받은 토큰**으로 재설치합니다.

```bash
systemctl disable cloudflared
rm /etc/systemd/system/cloudflared.service
systemctl daemon-reexec
systemctl daemon-reload

sudo cloudflared service install <TUNNEL_TOKEN>
```

`<TUNNEL_TOKEN>`을 [1. Cloudflare에서 터널 생성](#1-cloudflare에서-터널-생성)에서 복사한 값으로 바꿉니다.

서비스 상태 확인:

```bash
systemctl status cloudflared
```

## 3. Public Hostname — 서브도메인 연결

Zero Trust **Tunnels → 해당 터널 → Public Hostname**에서 NPM에 넣던 것과 같이 **서브도메인 → 내부 URL**을 등록합니다.

| 필드 | 예시 |
|------|------|
| Subdomain | `proxmox` |
| Domain | `example.com` |
| Service type | HTTP / HTTPS |
| URL | `https://<PROXMOX_IP>:8006` |

필요한 서비스마다 Hostname을 추가합니다 (HA, grocy, LubeLogger 등).

### HTTPS 백엔드 (Proxmox 등)

대상이 **자체 서명 HTTPS**(Proxmox 웹 UI 등)이면 **Additional application settings → TLS → No TLS Verify** 를 켭니다.

그렇지 않으면 cloudflared가 백엔드 인증서 검증에 실패할 수 있습니다.

## 4. DNS 확인

Cloudflare **DNS → Records**에서 Public Hostname 추가 시 **CNAME** 레코드가 자동 생성되었는지 확인합니다.

| Type | Name | Content (예) |
|------|------|----------------|
| CNAME | `proxmox` | `<tunnel-id>.cfargotunnel.com` |

## 5. Home Assistant — trusted_proxies

Home Assistant를 터널 뒤에 두는 경우, **packages**로 `http` 설정을 둡니다.

→ [homeassistant/packages/http.yaml](../homeassistant/packages/http.yaml) · [http.md](../homeassistant/packages/http.md)

| 항목 | 설명 |
|------|------|
| `172.30.33.0/24` | HA OS 내부(슈퍼바이저/애드온) 대역 |
| `<CLOUDFLARED_LXC_IP>` | cloudflared LXC LAN IP |

`/config/packages/http.yaml`에 배치 후 HA 재시작. LXC 설치: [README.md](README.md)

## 6. NPM과의 관계

| 방식 | 설명 |
|------|------|
| 기존 | Cloudflare DNS → 공인 IP → NPM → 내부 서비스 |
| 터널 | Cloudflare → cloudflared → 내부 서비스 (**포트포워딩·NPM 생략 가능**) |

동일 도메인에 NPM과 터널 Hostname을 **혼용하지 않도록** DNS·경로를 정리합니다.

## 7. 문제 해결

| 증상 | 조치 |
|------|------|
| 터널 Offline | LXC에서 `systemctl status cloudflared`, 토큰 재설치 |
| 502 / 연결 실패 | Public Hostname의 내부 URL·포트, LXC → 대상 서버 통신 |
| Proxmox HTTPS 오류 | **No TLS Verify** 활성화 |
| HA 로그인·IP 오류 | `trusted_proxies`에 cloudflared LXC IP 추가 |

## 8. 보안

- `<TUNNEL_TOKEN>`은 **한 번 노출되면 터널 제어 가능** — secrets·git에 저장하지 않음
- Zero Trust **Access 정책**으로 URL별 인증 추가 권장
- 내부 서비스를 모두 노출하지 말고 필요한 Hostname만 등록
