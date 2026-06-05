# Grandstream HT801/HT802

**Language:** [한국어](grandstream-ht801-ht802.md) · [English](grandstream-ht801-ht802.en.md)

[Grandstream](https://www.grandstream.com/) HT801/HT802 ATA를 FreePBX PJSIP 내선으로 등록합니다.

LXC·PBX: [README.md](README.md) · HA AMI: [ha-asterisk.md](ha-asterisk.md)

## 1. 사전 조건 (FreePBX 내선)

HT801/802를 연결하기 전에 PBX에서 내선(Extension)을 먼저 만듭니다.

1. FreePBX 웹 관리자 접속 → **Applications → Extensions**
2. **Add Extension → Add New PJSIP Extension**
3. 아래 항목 입력 후 저장:
   - **User Extension:** 내선 번호 (예: `<TARGET_EXT>`)
   - **Display Name:** 표시 이름 (임의)
   - **Secret:** 인증 비밀번호 (ATA 설정에 필요 — 별도 기록)
4. 우측 상단 **Apply Config**로 변경 사항 적용

HA 연동은 **별도 SIP 등록이 아니라 FreePBX AMI**로 합니다. → [ha-asterisk.md](ha-asterisk.md)

## 2. ATA 웹 설정 페이지 접속

1. HT801/802의 `Phone` 포트에 아날로그 전화기 연결
2. 수화기를 들고 **`***`** 입력 → 음성 안내 후 **`02`**로 IP 확인
3. 브라우저에 해당 IP 입력 → 관리자 페이지 접속 (기본 계정은 장비 라벨·매뉴얼 참고)

## 3. Profile / FXS Port 설정

상단 **PROFILES** (구형 펌웨어는 **FXS PORTS**)에서 아래와 같이 매핑합니다.

설정 항목이 많으면 브라우저 검색으로 Parameter 이름을 찾습니다.

| 설정 항목 (Parameter) | 권장 설정값 (Value) | 설명 |
|------|------|------|
| **Account Active** | `Yes` | 해당 포트 활성화 |
| **Primary SIP Server** | `<FREEPBX_IP>` | FreePBX LAN IP |
| **SIP Transport** | `UDP` | 기본 프로토콜 |
| **SIP Registration** | `Yes` | 서버 등록 활성화 |
| **SIP User ID** | `<TARGET_EXT>` | FreePBX **내선 번호** |
| **Authenticate ID** | `<TARGET_EXT>` | 내선 번호와 동일 |
| **Authenticate Password** | *(Secret)* | FreePBX 내선 Secret (**커밋하지 않음**) |
| **Name** | `<TARGET_EXT>` | 발신 시 표시 이름 (임의) |
| **Local SIP Port** | `5060` | FreePBX PJSIP 포트 |

## 4. 대한민국 전화 환경 (선택)

국내 아날로그 전화기 호환·신호음 통일을 위해 권장합니다.

- **SLIC Setting:** `CHINA CO` 또는 `STANDARD 900 ohms` (임피던스·벨소리 찢어짐 완화)
- **Caller ID Scheme:** `Bellcore/Telcordia` (국내 CID 표시)
- **Preferred Vocoder:**
  - Choice 1: **PCMA** (G.711a)
  - Choice 2: **PCMU** (G.711u)

## 5. 저장 및 연결 확인

1. 페이지 하단 **Save** 또는 **Apply**
2. 재부팅 후 상단 **STATUS** 메뉴 이동
3. `Port Status` → `Registration`이 **Registered**(녹색)이면 연동 완료

등록 실패 시: PBX IP·Secret·방화벽(UDP 5060, RTP 범위), **Apply Config** 적용 여부를 확인합니다.

## 6. 펌웨어 업데이트

최신 펌웨어·릴리스 노트: [Grandstream Firmware and Release Notes](https://www.grandstream.com/support/firmware)

페이지에서 **Gateways and ATA's → HandyTone ATA's** 구역의 **HT801 V2** / **HT802 V2** 행을 찾습니다. **Release Notes**를 먼저 읽고, 필요하면 ZIP을 받아 수동 업로드합니다. (문서 작성 시점 기준 최신 안정 버전 예: `1.0.11.4` — 사이트에 표시된 버전을 따르세요.)

Grandstream은 펌웨어 업그레이드를 **HTTP**로 할 것을 권장하며, 공개 업그레이드 서버도 HTTP입니다. `Firmware Server Path`에는 `http://` 접두사를 넣지 않습니다.

### 업그레이드 전

1. **STATUS**에서 현재 펌웨어 버전 확인
2. SIP 연동 설정 백업: **Advanced Settings** (또는 **Maintenance**)에서 **Download Device Configuration** / XML보내기, 또는 화면 설정을 별도 기록
3. 업그레이드 중 전화·등록이 잠시 끊깁니다

### 방법 A: HTTP 서버에서 자동 업그레이드 (권장)

ATA 웹 UI → **Advanced Settings** (일부 펌웨어는 **Maintenance → Upgrade and Provisioning**) → **Firmware Upgrade and Provisioning**:

| 항목 | 설정 |
|------|------|
| **Always Check for New Firmware** | `Yes` |
| **Upgrade via** | `HTTP` |
| **Firmware Server Path** | `firmware.grandstream.com` |

1. 하단 **Save** → **Apply**
2. **Reboot** 후 완료될 때까지 대기 (전원 LED·웹 UI 복구 확인)
3. **STATUS**에서 펌웨어 버전이 올라갔는지 확인 후, 필요하면 위 **Profile / FXS Port** 설정이 유지됐는지 검증

부팅 시 자동으로 새 펌웨어를 확인하도록 두려면 **Always Check for New Firmware**를 켠 채로 두면 됩니다.

### 방법 B: PC에서 파일 업로드

1. [펌웨어 페이지](https://www.grandstream.com/support/firmware)에서 해당 모델(HT801 V2 / HT802 V2) **다운로드** 링크로 ZIP 받기
2. 압축 해제 — 모델별 바이너리 예: `ht801fw.bin`, `ht802fw.bin` (ZIP 안 파일명·매뉴얼 확인)
3. 웹 UI **Advanced Settings** → **Upload Firmware** → 파일 선택 → **Apply** / **Reboot**

### HT801/802 V2 주의사항

- **1.0.9.3 이상**으로 올린 뒤 **1.0.7.5 이하로 다운그레이드는 지원되지 않습니다** (공식 Release Notes 문구).
- 표에 `*`가 붙은 펌웨어는 제한적 수정·기능만 포함할 수 있으므로 Release Notes를 반드시 확인합니다.
- 다운그레이드·공장 초기화가 필요한 경우, 업그레이드 **전** 백업 파일을 보관합니다.

### 업그레이드 후

1. **STATUS → Port Status → Registration**이 다시 **Registered**인지 확인
2. 내선·코덱·한국 환경 설정(4절)이 초기화됐으면 **Profile / FXS Port**를 재적용
3. 문제가 있으면 백업 XML **Upload Configuration**으로 복원 (버전 호환은 Release Notes 참고)
