# Cloudflare DDNS 설정

**Language:** [한국어](ddns-setup.md) · [English](ddns-setup.en.md)

공유기·회선의 **공인 IPv4(·IPv6)** 가 바뀔 때 Cloudflare DNS 레코드를 자동으로 맞춥니다. [Cloudflare Tunnel](../cloudflared/tunnel-setup.md)과 별개로, **DNS만 DDNS로 갱신**할 때 사용합니다.

```
공인 IP 변경 감지 ──► cloudflare-ddns LXC ──► Cloudflare API ──► DNS A/AAAA 갱신
```

## 사전 조건

- Cloudflare에 **도메인** 등록·위임 완료
- [cloudflare-ddns LXC](https://community-scripts.org/scripts/cloudflare-ddns) 설치 완료

## 1. Cloudflare API 토큰

1. [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens) → **Create Token**
2. **Edit zone DNS** 템플릿 사용 또는 수동 권한:
   - Zone → DNS → **Edit**
   - 대상 Zone: 해당 도메인만
3. 토큰 복사 — `<CLOUDFLARE_API_TOKEN>` (**git·문서에 커밋하지 않음**)

상세: [favonia/cloudflare-ddns README](https://github.com/favonia/cloudflare-ddns) — API 토큰 권한 안내

## 2. 설치 시 마법사 (최초)

LXC 설치 스크립트가 대화형으로 묻는 항목:

| 질문 | 예시 | 설명 |
|------|------|------|
| API token | (토큰 값) | [1. Cloudflare API 토큰](#1-cloudflare-api-토큰)에서 발급 |
| Domains | `home.example.com,*.example.com` | 쉼표로 구분, 와일드카드 가능 |
| Proxied? | `y` / `n` | Cloudflare **주황 구름**(프록시) 사용 여부 |
| IPv6 support? | `y` / `n` | `y` → `IP6_PROVIDER=cloudflare.trace`, `n` → `none` |

설치 스크립트가 `/etc/systemd/system/cloudflare-ddns.service`에 환경 변수를 기록하고 `cloudflare-ddns` 서비스를 시작합니다.

## 3. 설정 변경 (설치 후)

LXC 콘솔에서 서비스 유닛을 편집합니다.

```bash
nano /etc/systemd/system/cloudflare-ddns.service
```

`[Service]`의 `Environment=` 줄을 수정합니다.

```ini
[Service]
Environment="CLOUDFLARE_API_TOKEN=<CLOUDFLARE_API_TOKEN>"
Environment="DOMAINS=home.example.com,*.example.com"
Environment="PROXIED=false"
Environment="IP6_PROVIDER=none"
```

적용:

```bash
systemctl daemon-reload
systemctl restart cloudflare-ddns
systemctl status cloudflare-ddns
```

community-scripts 안내와 동일: 설정 변경 후 **`systemctl restart cloudflare-ddns`**

## 4. 주요 환경 변수

| 변수 | 설명 | 예시 |
|------|------|------|
| `CLOUDFLARE_API_TOKEN` | API 토큰 (필수) | [1. Cloudflare API 토큰](#1-cloudflare-api-토큰) |
| `DOMAINS` | A·AAAA 모두 갱신할 FQDN (쉼표 구분) | `ddns.example.com` |
| `IP4_DOMAINS` | **A 레코드만** (IPv4) | `home.example.com` |
| `IP6_DOMAINS` | **AAAA만** (IPv6) | `home.example.com` |
| `PROXIED` | `true` / `false` | 터널·숨김 IP vs DNS only |
| `IP6_PROVIDER` | IPv6 감지 | `none`, `cloudflare.trace` 등 |

`DOMAINS`와 `IP4_DOMAINS`·`IP6_DOMAINS`는 **함께 사용 가능**(additive).  
전체 목록: [favonia/cloudflare-ddns — environment variables](https://github.com/favonia/cloudflare-ddns)

### Proxied 선택

| 값 | 용도 |
|----|------|
| `false` | **DDNS 전용** — 공인 IP가 DNS에 그대로 기록 (동적 IP 노출) |
| `true` | Cloudflare CDN·WAF 경유 — 실제 IP 숨김 ([Tunnel](../cloudflared/tunnel-setup.md)과 함께 쓸 때도 흔함) |

## 5. 동작 확인

1. `journalctl -u cloudflare-ddns -f` — 갱신 로그 확인
2. Cloudflare **DNS → Records** — 대상 레코드 IP가 현재 공인 IP와 일치하는지 확인
3. 공인 IP 변경 후(재부팅·회선 재연결) 자동 갱신 여부 확인

## 6. Tunnel과 함께 쓸 때

| 구성 | DDNS | Tunnel |
|------|------|--------|
| 동적 공인 IP + NPM/포트포워딩 | DDNS로 `home.example.com` → 현재 IP | — |
| 고정 없이 서비스 노출 | — | [cloudflared](../cloudflared/tunnel-setup.md) Public Hostname |
| 혼용 | DDNS 레코드와 Tunnel CNAME **충돌 주의** | Hostname별 DNS 자동 생성 |

같은 호스트명에 DDNS A 레코드와 Tunnel CNAME을 동시에 두지 않도록 정리합니다.

## 7. 문제 해결

| 증상 | 조치 |
|------|------|
| API token invalid | 토큰 권한(Zone DNS Edit)·Zone 범위 확인 |
| 레코드 미갱신 | `DOMAINS` 철자, `systemctl status cloudflare-ddns` |
| IPv6 오류 | `IP6_PROVIDER=none` 으로 IPv4만 사용 |
| 설정 반영 안 됨 | `daemon-reload` 후 `restart` |

## 8. 보안

- `CLOUDFLARE_API_TOKEN`은 `cloudflare-ddns.service`에만 두고 **저장소에 커밋하지 않음**
- 토큰은 **최소 권한**(해당 Zone DNS Edit만)
