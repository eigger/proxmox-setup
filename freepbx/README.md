# FreePBX

**Language:** [한국어](README.md) · [English](README.en.md)

[FreePBX](https://www.freepbx.org/) — [Asterisk](https://www.asterisk.org/) 기반 IP-PBX. Proxmox LXC로 셀프호스팅하고 Grandstream ATA·Home Assistant와 연동할 때 참고합니다.

## 설치

Proxmox VE **LXC** 설치 스크립트: [FreePBX — Proxmox VE Helper Scripts](https://community-scripts.org/scripts/freepbx)

공식 [FreePBX Debian 설치 스크립트](https://github.com/FreePBX/sng_freepbx_debian_install)를 사용합니다.

1. Proxmox 호스트 **Shell**에서 아래 명령 실행
2. 마법사에서 **Default** 또는 **Advanced** 선택 후 LXC 생성

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/freepbx.sh)"
```

설치 후 웹 UI: `http://<FREEPBX_IP>` (기본 포트 **80**)

### 초기 설정

1. 고정 IP·호스트명·DNS 설정
2. 웹 UI에서 초기 관리자 계정 설정
3. SIP/RTP·HTTPS(443) 방화벽 허용
4. **Connectivity → Trunks / Extensions** — 내선 생성 후 **Apply Config**

## 장비 연동

| 주제 | 문서 |
|------|------|
| Grandstream HT801/HT802 (SIP 내선) | [grandstream-ht801-ht802.md](grandstream-ht801-ht802.md) |

## Home Assistant 연동

AMI·ha-sip는 **애드온·UI·자동화** 기반이라 `homeassistant/packages/` 조합본은 없습니다.

| 연동 가이드 | 문서 |
|-------------|------|
| AMI (`asterisk.send_action`) | [ha-asterisk.md](ha-asterisk.md) |
| ha-sip (SIP + Edge TTS) | [ha-sip.md](ha-sip.md) |
| HA packages·secrets 구조 | [homeassistant/config-structure.md](../homeassistant/config-structure.md) |

## 환경 (플레이스홀더)

| 장비 | IP | 비고 |
|------|-----|------|
| FreePBX | `<FREEPBX_IP>` | PBX LAN 주소 |
| Home Assistant | `<HA_IP>` | AMI·ha-sip 대상 |
| Grandstream ATA | DHCP/고정 | 내선 예: `<TARGET_EXT>` |
| ha-sip (HA) | — | SIP 내선 `<HA_SIP_EXT>` |

### 포트 (기본)

| 용도 | 포트 | 프로토콜 |
|------|------|----------|
| SIP | 5060 | UDP/TCP |
| SIP TLS | 5061 | TCP |
| AMI | 5038 | TCP |
| RTP | 10000–20000 | UDP |
| HTTPS | 443 | TCP |

NAT 환경에서는 Proxmox·공유기 포트포워딩과 FreePBX `External Address`가 일치해야 합니다.

### 구성 요약

```
[HA]  AMI :5038 ──────────────┐
[HA]  ha-sip :5060 ───────────┼──► [FreePBX] ──SIP──► [Grandstream]
```

1. PJSIP Extension 생성
2. Grandstream 등록 → [grandstream-ht801-ht802.md](grandstream-ht801-ht802.md)
3. (선택) AMI → [ha-asterisk.md](ha-asterisk.md)
4. (선택) ha-sip → [ha-sip.md](ha-sip.md)

## 폴더 구조

```
freepbx/
├── README.md
├── grandstream-ht801-ht802.md
├── ha-asterisk.md           # HA AMI 연동
└── ha-sip.md                # HA ha-sip 애드온
```

## 비밀값

SIP 트렁크·Extension Secret·AMI Secret·API 키는 **커밋하지 않습니다**.

### 백업

- FreePBX **Backup & Restore** 모듈 또는 `fwconsole backup`
- Proxmox 호스트: [proxmox/gdrive-backup.md](../proxmox/gdrive-backup.md)
