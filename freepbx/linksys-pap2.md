# Linksys PAP2 / PAP2T

**Language:** [한국어](linksys-pap2.md) · [English](linksys-pap2.en.md)

Linksys PAP2 또는 PAP2T ATA(Analog Telephone Adapter)를 FreePBX PJSIP 내선으로 등록합니다.

LXC·PBX: [README.md](README.md) · HA AMI: [ha-asterisk.md](ha-asterisk.md)

## 1. 사전 조건 (FreePBX 내선)

PAP2를 연결하기 전에 PBX에서 내선(Extension)을 먼저 만듭니다.

1. FreePBX 웹 관리자 접속 → **Applications → Extensions**
2. **Add Extension → Add New PJSIP Extension**
3. 아래 항목 입력 후 저장:
   - **User Extension:** 내선 번호 (예: `<TARGET_EXT>`)
   - **Display Name:** 표시 이름 (임의)
   - **Secret:** 인증 비밀번호 (ATA 설정에 필요 — 별도 기록)
4. 우측 상단 **Apply Config**로 변경 사항 적용

## 2. ATA 웹 설정 페이지 접속

1. PAP2의 `Line 1` 포트에 아날로그 전화기 연결
2. 수화기를 들고 **`****`** (별표 4개) 입력 → 음성 안내 후 **`110#`**으로 IP 확인
3. 브라우저에 해당 IP 입력 → 관리자 페이지 접속
4. 우측 상단의 **Admin Login** 클릭 → **switch to advanced view** 클릭 (고급 설정 모드 활성화)

## 3. Line 설정 (SIP 등록)

상단 **Line 1** (또는 Line 2) 탭으로 이동하여 아래와 같이 설정합니다.

| 설정 항목 (Parameter) | 권장 설정값 (Value) | 설명 |
|------|------|------|
| **Line Enable** | `yes` | 해당 라인 활성화 |
| **Proxy** | `<FREEPBX_IP>` | FreePBX LAN IP (포트가 다를 경우 `<FREEPBX_IP>:<PORT>` 형태로 지정. 예: `<FREEPBX_IP>:5060`) |
| **Register** | `yes` | 서버 등록 활성화 |
| **Register Expires** | `3600` | 등록 만료 주기 (초 단위) |
| **Display Name** | `<TARGET_EXT>` | 발신 시 표시 이름 (임의) |
| **User ID** | `<TARGET_EXT>` | FreePBX **내선 번호** |
| **Password** | *(Secret)* | FreePBX 내선 Secret (**커밋하지 않음**) |
| **Use Auth ID** | `yes` | 인증 ID 사용 설정 |
| **Auth ID** | `<TARGET_EXT>` | 내선 번호와 동일 |
| **NAT Mapping Enable** | `no` / `yes` | 공유기 뒤에 있을 경우 `yes` (로컬망인 경우 `no`) |
| **NAT Keep Alive Enable** | `yes` | NAT 유지 패킷 송신 |
| **SIP Port** | `5060` (Line 1) / `5061` (Line 2) | PAP2 장비 자체의 로컬 수신 포트 |

## 4. 대한민국 전화 환경 (선택)

국내 아날로그 전화기 호환 및 대한민국 표준 신호음(톤) 조정을 위해 권장합니다.

### Regional 탭 설정

상단 **Regional** 탭으로 이동하여 아래 항목들을 수정합니다.

#### Call Progress Tones (통화 진행 톤)
- **Dial Tone:** `350@-19,440@-19;30(*/0/1+2)` (대한민국 표준 발신음)
- **Busy Tone:** `480@-19,620@-19;10(.25/.25/1+2)` (통화 중 신호음)
- **Reorder Tone:** `480@-19,620@-19;10(.25/.25/1+2)`
- **Ring Back Tone:** `440@-19,480@-19;20(.5/2/1+2)` (대한민국 표준 수신 대기음 - 1초 On / 2초 Off 패턴 근사치)

#### Ring Cadence (벨소리 주기)
- **Ring1 Cadence:** `60(1/2)` (대한민국 표준: 1초 벨소리 후 2초 멈춤) 또는 `60(2/4)` (북미 표준: 2초 벨소리 후 4초 멈춤)
  - *팁: 벨이 울리는 시간과 멈추는 시간을 늘리려면 괄호 안의 숫자를 초 단위로 수정합니다. 문법은 `60(울리는시간/멈추는시간)` 입니다. (예: `60(2/5)`는 2초 동안 울리고 5초 동안 멈춤, `60(1.5/3.5)` 등 소수점 단위도 가능)*

#### Miscellaneous
- **Time Zone:** `GMT+09:00` (대한민국 표준시)
- **FXS Port Impedance:** `600` (대한민국 표준 600옴 임피던스)


## 5. 저장 및 연결 확인

1. 페이지 하단 **Save Settings** 클릭
2. 재부팅 후 상단 **Info** 탭으로 이동
3. `Line 1 Status` / `Line 2 Status`의 **Registration State**가 **Registered**인지 확인

등록 실패 시: FreePBX IP, Extension Secret, 방화벽(UDP 5060, RTP 포트 범위), FreePBX에서 **Apply Config**가 정상 적용되었는지 재확인합니다.

## 6. 공장 초기화 (참고)

중고 기기이거나 이전 프로비저닝 설정이 꼬인 경우 초기화를 권장합니다.

1. 전화기 수화기를 들고 **`****`** 입력
2. 음성 안내가 나오면 **`73738#`** (R-E-S-E-T) 입력
3. 확인 안내가 나오면 **`1`**을 눌러 확인 및 재부팅
