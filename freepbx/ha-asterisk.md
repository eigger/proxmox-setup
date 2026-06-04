# Home Assistant ↔ FreePBX (AMI)

Grandstream 아날로그 내선은 **FreePBX(SIP)** 에만 등록하고, Home Assistant는 **AMI(5038)** 로 PBX를 제어합니다. HA Asterisk **애드온은 불필요**합니다.

SIP로 HA에 **Edge TTS·웹훅 수신**까지 쓰려면 [ha-sip.md](ha-sip.md) (arnonym **ha-sip** 애드온)을 함께 참고합니다.

## 환경 (예시)

`<HA_IP>`, `<FREEPBX_IP>`는 각각 Home Assistant·FreePBX의 **LAN 주소**로 바꿉니다 (저장소에는 실제 IP를 넣지 않음).

| 장비 | IP | 역할 |
|------|-----|------|
| Home Assistant | `<HA_IP>` | 자동화·`asterisk.send_action` |
| FreePBX | `<FREEPBX_IP>` | PBX, AMI, PJSIP 내선 |
| Grandstream HT801/802 | (DHCP/고정) | 내선 `1001` 등 → [grandstream-ht801-ht802.md](grandstream-ht801-ht802.md) |

```
HA ──AMI 5038──► FreePBX ──SIP 5060──► Grandstream (아날로그 전화)
```

## SIP 등록 vs AMI (헷갈리기 쉬운 점)

| | Grandstream | Home Assistant |
|--|-------------|----------------|
| 프로토콜 | SIP | AMI (Manager) |
| 포트 | 5060 | 5038 |
| 계정 | Extension + **Secret** | **Asterisk Manager User** + Secret |
| GUI 표시 | PJSIP **Registered** | Asterisk **통합** 연결 |

내선이 Registered여도 HA는 **`bindaddr`·Manager User** 없으면 연결되지 않습니다.

---

## 1. FreePBX — Asterisk Manager User

**Settings → Advanced Settings → Asterisk Manager Users**

| 필드 | 값 (예시) |
|------|-----------|
| Name | `Homeassistant` (HA Username과 **동일**, 대소문자 포함) |
| Secret | AMI 전용 비밀번호 (**FreePBX 웹 로그인 비번 아님**) |
| Deny | `0.0.0.0/0.0.0.0` |
| Permit | `127.0.0.1/255.255.255.255` |
| | `<HA_IP>/255.255.255.255` |
| Write Timeout | `5000` |

Read/Write에 **`originate`** 포함 (필요 시 report 등 추가).

**Submit** → **Apply Config**

다른 계정(`cdrpro_events`, `srtapi_*` 등)은 `127.0.0.1`만 허용하는 **내부용** — 수정 불필요.

---

## 2. FreePBX — AMI Bind Address (필수)

FreePBX 16+ 기본: **Bind Address `127.0.0.1`** → LAN에서 `5038` **Connection refused**.

Asterisk Manager Users 페이지 안내 예:

> AMI current settings for Bind Address : 127.0.0.1 and bind port : 5038

### GUI Config Edit는 불가

`manager.conf`는 FreePBX가 **자동 생성** → Config Edit에서 **File is not writable** 가 정상.

### CLI에서 수정

```bash
nano /etc/asterisk/manager.conf
```

`[general]`:

```ini
bindaddr = 0.0.0.0
port = 5038
```

파일 하단에 include 유지:

```ini
#include manager_additional.conf
#include manager_custom.conf
```

적용:

```bash
fwconsole reload
asterisk -rx "manager show settings"
```

`TCP Bindaddress: 0.0.0.0:5038` 확인.

참고: [FreePBX 16 AMI 기본 설정](https://sangomakb.atlassian.net/wiki/spaces/PG/pages/26706045/PBX+GUI+-+AMI+Default+Configuration+in+16)

> GUI **Apply Config** 후 `bindaddr`가 다시 `127.0.0.1`로 돌아가면 재수정. 반복 시 `chattr +i /etc/asterisk/manager.conf` 검토(업데이트 전 `chattr -i`).

---

## 3. 연결 확인

### Mac / HA 호스트

```bash
nc -zv <FREEPBX_IP> 5038
```

`succeeded` / `open` 이어야 함.

### AMI 로그인

```bash
(
  printf 'Action: Login\r\nUsername: Homeassistant\r\nSecret: YOUR_AMI_SECRET\r\n\r\n'
  sleep 2
) | nc <FREEPBX_IP> 5038
```

`Authentication accepted` 확인.

---

## 4. Home Assistant — Asterisk 통합

[HACS: asterisk-hass-integration](https://github.com/TECH7Fox/asterisk-hass-integration) 설치 후 **설정 → 통합 → Asterisk**.

| 항목 | 값 |
|------|-----|
| Host | `<FREEPBX_IP>` |
| Port | `5038` |
| Username | `Homeassistant` |
| Password | Manager **Secret** |

문서: [Send Action Service](https://tech7fox.github.io/sip-hass-docs/docs/integration/services/send_action)

성공 시 PJSIP 내선이 HA **기기**로 표시됩니다.

---

## 5. `asterisk.send_action` — 내선으로 전화·재생

서비스: **`asterisk.send_action`** — AMI `Originate` 등 전달.

> `timeout`은 **밀리초** (예: 60초 = `60000`).

### 개발자 도구 (Playback)

FreePBX에 음원 ` /var/lib/asterisk/sounds/custom/ha-alert.wav` 가 있다고 가정 (확장자 없이 `custom/ha-alert`).

```yaml
action: Originate
parameters:
  channel: PJSIP/1001
  application: Playback
  data: custom/ha-alert
  callerid: "Home Assistant"
  timeout: 60000
```

### 다이얼플랜 컨텍스트 사용

`extensions_custom.conf`에 `[ha-tts]` 정의 후:

```yaml
action: Originate
parameters:
  channel: PJSIP/1001
  context: ha-tts
  exten: s
  priority: "1"
  callerid: "Home Assistant"
  timeout: 60000
```

### 자동화 예시

```yaml
automation:
  - alias: "집 전화 알림"
    triggers:
      - platform: state
        entity_id: binary_sensor.example
        to: "on"
    actions:
      - action: asterisk.send_action
        data:
          action: Originate
          parameters:
            channel: PJSIP/1001
            application: Playback
            data: custom/ha-alert
            callerid: "Home Assistant"
            timeout: 60000
```

### FreePBX CLI 테스트 (HA 없이)

```bash
asterisk -rx "channel originate PJSIP/1001 application Playback custom/ha-alert"
```

---

## 6. TTS 연동 (다음 단계)

1. HA `tts.speak` 등으로 문장 → wav 생성  
2. 8 kHz mono 등 Asterisk 호환 형식으로 `/var/lib/asterisk/sounds/custom/` 에 복사 (scp/SSH)  
3. `asterisk.send_action` → `Playback` `custom/파일명`

동적 문장·Polly 모듈은 FreePBX AGI/모듈로 확장 가능.

### `ha-tts` 다이얼플랜 예시

**Admin → Config Edit** 또는 `/etc/asterisk/extensions_custom.conf`:

```ini
[ha-tts]
exten => s,1,NoOp(HA TTS)
 same => n,Answer()
 same => n,Wait(1)
 same => n,Playback(custom/ha-alert)
 same => n,Hangup()
```

**Apply Config** 후 `asterisk -rx "dialplan show ha-tts"` 확인.

---

## 7. 문제 해결

| 증상 | 원인 | 조치 |
|------|------|------|
| `nc` Connection refused | `bindaddr = 127.0.0.1` | `0.0.0.0` + reload |
| HA Cannot connect to AMI | 위 + 잘못된 Password | Manager Secret, Host IP |
| Authentication failed | 웹 admin 비번 / 내선 Secret 사용 | AMI Secret만 |
| failed to pass IP ACL | Permit에 HA IP 없음 | `<HA_IP>/255.255.255.255` 추가 |
| 전화 즉시 종료 | timeout 너무 짧음 | `60000` 등 |
| Grandstream OK, HA만 실패 | SIP ≠ AMI | 이 문서 2절 |

---

## 8. 보안

- `bindaddr = 0.0.0.0` 시 **Manager User Permit**으로 IP 제한 (`Homeassistant` → HA만).
- AMI Secret·Extension Secret은 저장소에 커밋하지 않음.
- 공유기에서 5038 **포트포워딩 금지** (LAN 내부만).
