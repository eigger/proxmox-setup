# FreePBX

Proxmox VM에 FreePBX Distro(또는 Debian + FreePBX)를 올리고 운영하는 방법입니다.

## 환경 (LAN)

`<FREEPBX_IP>`, `<HA_IP>`는 실제 LAN 주소로 교체합니다.

| 장비 | IP (플레이스홀더) |
|------|-----------|
| FreePBX VM | `<FREEPBX_IP>` |
| Home Assistant | `<HA_IP>` |
| Grandstream ATA | DHCP/고정 (내선 예: `1001`) |

## 권장 사양 (VM)

| 항목 | 권장 |
|------|------|
| OS | [FreePBX Distro](https://www.freepbx.org/downloads/) ISO |
| vCPU | 2 |
| RAM | 4 GB (소규모 2 GB) |
| 디스크 | 32 GB+ (녹음·로그 사용 시 여유) |
| 네트워크 | 브리지 `vmbr0` (SIP/RTP용 고정 IP 권장) |

## 설치 흐름

1. Proxmox에서 VM 생성 → ISO 부팅 → FreePBX Distro 설치
2. 고정 IP·호스트명·DNS 설정
3. 웹 UI: `https://<freepbx-ip>/` (초기 관리자 계정 설정)
4. SIP/RTP·HTTPS(443) 방화벽 허용
5. **Connectivity → Trunks / Extensions** — 내선 생성 후 **Apply Config**

## 포트 (기본)

| 용도 | 포트 | 프로토콜 |
|------|------|----------|
| SIP (내부/트렁크) | 5060 | UDP/TCP |
| SIP TLS | 5061 | TCP |
| AMI (HA 등) | 5038 | TCP |
| RTP (음성) | 10000–20000 | UDP |
| HTTPS (관리) | 443 | TCP |
| SSH (선택) | 22 | TCP |

NAT 뒤에 두는 경우 **외부에서 들어오는 SIP/RTP**는 Proxmox 호스트·공유기 포트포워딩과 FreePBX `External Address` 설정이 맞아야 합니다.

## 연동 가이드

| 주제 | 문서 |
|------|------|
| Grandstream HT801/HT802 (SIP 내선) | [grandstream-ht801-ht802.md](grandstream-ht801-ht802.md) |
| Home Assistant (AMI, 전화·TTS) | [ha-asterisk.md](ha-asterisk.md) |

## 구성 요약

```
[HA]  asterisk.send_action / AMI :5038
         ↓
[FreePBX]  PJSIP 내선, 다이얼플랜, Playback
         ↓
[Grandstream]  아날로그 전화
```

1. FreePBX에 PJSIP Extension 생성  
2. Grandstream을 내선으로 등록 → [grandstream 가이드](grandstream-ht801-ht802.md)  
3. AMI `bindaddr` + Manager User → [HA 가이드](ha-asterisk.md)  
4. HA에서 `Originate`로 내선 호출·`Playback` 안내  

## 비밀값·백업

- SIP 트렁크·Extension Secret·AMI Secret·API 키는 **커밋하지 않습니다**.
- 설정 백업: FreePBX **Backup & Restore** 모듈 또는 `fwconsole backup`
- Proxmox 호스트 백업: [proxmox/gdrive-backup.md](../proxmox/gdrive-backup.md)
