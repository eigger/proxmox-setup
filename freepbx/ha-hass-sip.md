# Home Assistant SIP Client (hass-sip) ↔ FreePBX

**Language:** [한국어](ha-hass-sip.md) · [English](ha-hass-sip.en.md)

[eigger/hass-sip](https://github.com/eigger/hass-sip) 커스텀 통합 구성요소를 사용하여 Home Assistant(HA)를 FreePBX에 **SIP 클라이언트**로 직접 등록합니다. HA 내부에서 네이티브 `media_player` 엔티티로 작동하여 제어 및 TTS 재생이 매우 간편하며, 다양한 제어 엔티티(스위치/버튼), 이벤트 엔티티, 보이스 어시스트 연동, 주소록 매핑, 수신 전화 제어 대시보드 구성을 지원합니다.

LXC 설치·포트: [README.md](README.md) · `homeassistant/packages/` 조합본 없음 (통합 구성요소 및 자동화 서비스 기반)

---

## 환경 (플레이스홀더)

| 항목 | 예시 | 설명 |
|:---|:---|:---|
| FreePBX | `<FREEPBX_IP>` | FreePBX LAN 주소 |
| hass-sip 내선 | `<HA_SIP_EXT>` | HA 전용 SIP Extension (예: `100`) |
| 대상 전화/내선 | `<TARGET_EXT>` | Grandstream ATA 또는 기타 소프트폰 (예: `1001`) |

```
HA (hass-sip) ──SIP 5060──► FreePBX ──SIP 5060──► Grandstream ATA (전화기)
```

---

## 1. FreePBX — PJSIP 내선 생성

1. FreePBX 웹 UI 접속 (`http://<FREEPBX_IP>`)
2. **Applications → Extensions → Add Extension → Add New PJSIP Extension** 클릭
3. 아래 정보 입력:
   - **User Extension:** `<HA_SIP_EXT>` (예: `100`)
   - **Display Name:** `Home Assistant`
   - **Secret:** 암호 입력 (HA 통합 설정 시 필요하므로 기록해 둡니다)
4. **Submit** 버튼 클릭 후 우측 상단의 **Apply Config**를 눌러 설정을 반영합니다.

---

## 2. Home Assistant — 통합 구성요소 설치 및 등록

### HACS 설치
1. HA 웹 UI에서 **HACS** 메뉴로 이동합니다.
2. 우측 상단의 점 3개 메뉴를 누르고 **사용자 지정 저장소 (Custom repositories)**를 선택합니다.
3. 아래와 같이 입력하고 추가합니다:
   - **저장소:** `https://github.com/eigger/hass-sip`
   - **범주:** `Integration (통합 구성요소)`
4. 추가된 **SIP Client** 통합 구성요소를 다운로드합니다.
5. Home Assistant를 **재시작**합니다.

### 기기 추가 (UI 설정)
1. **설정 → 기기 및 서비스 → 통합 구성요소 추가** 클릭
2. **SIP Client** 검색 후 선택
3. 아래 설정값을 입력합니다:
   - **Server / Host:** `<FREEPBX_IP>` (FreePBX 주소)
   - **Port:** `5060`
   - **Username:** `<HA_SIP_EXT>` (예: `100`)
   - **Password:** `<FREEPBX_EXTENSION_SECRET>` (FreePBX 내선 비밀번호)
   - **Domain (선택):** 비워두면 Server 값으로 자동 지정됩니다.
   - **Caller ID (선택):** `Home Assistant`
   - **RTP Port (선택):** `7078`
4. 등록을 마치면 HA에 아래와 같은 엔티티들이 자동으로 생성됩니다.

---

## 3. 생성되는 제어 엔티티 (Control Entities)

`hass-sip`는 사용자의 대시보드 편의성과 자동화 편의를 돕기 위해 네이티브 스위치, 버튼 및 이벤트 엔티티를 자동으로 생성합니다.

### 스위치 (Switches)
* **방해 금지 스위치** (`switch.sip_client_dnd`): 이 스위치가 켜져(ON) 있으면 모든 수신 전화를 자동으로 거절하며 `486 Busy Here` SIP 응답 코드를 보냅니다.
* **자동 응답 스위치** (`switch.sip_client_auto_answer`): 이 스위치가 켜져(ON) 있으면 걸려오는 모든 전화를 벨 울림 없이 즉시 자동 응답합니다.

### 버튼 (Buttons)
* **응답 버튼** (`button.sip_client_answer`): 대시보드에서 수신 중인 전화를 수동으로 응답할 때 누르는 버튼입니다.
* **종료 버튼** (`button.sip_client_hangup`): 활성 통화를 종료하거나 수신 전화를 거절할 때 누르는 버튼입니다.

---

## 4. 서비스 호출 및 안내 방송 예시

HA 표준 TTS 엔진(Piper, Google Translate, Nabu Casa Cloud 등)을 사용할 수 있으며, 오디오 코덱 전송 및 리샘플링(ffmpeg)은 백그라운드에서 자동으로 처리됩니다.

### 옵션 A: 간소화된 파라미터 (권장 - 단발성 안내)
`sip.answer` 또는 `sip.dial` 서비스 호출 시 직접 `message`와 TTS 설정을 지정하면, 연결 → 안내 재생 → 재생 완료 후 자동 통화 종료(hangup)가 원스톱으로 처리됩니다.

#### 수신 시 자동 응답 후 메시지 읽고 끊기
```yaml
alias: "SIP: 수신 시 자동 응답 및 TTS 재생"
trigger:
  - platform: event
    event_type: sip_incoming_call
action:
  - service: sip.answer
    target:
      entity_id: media_player.sip_client
    data:
      message: "안녕하세요. 자동 안내 방송입니다."
      tts_engine: tts.google_translate
      language: ko
```

#### 지정 번호로 발신 후 상대가 받으면 메시지 읽고 끊기
```yaml
alias: "SIP: 전화 발신 및 TTS 안내"
action:
  - service: sip.dial
    target:
      entity_id: media_player.sip_client
    data:
      number: "sip:<TARGET_EXT>@<FREEPBX_IP>"
      ring_timeout: 30
      message: "택배가 도착했습니다."
      tts_engine: tts.google_translate
      language: ko
```

---

### 옵션 B: 멀티스텝 자동화 (상세 시나리오 제어)
전화 수신, 연결 성공, 재생 완료 등의 시점을 정밀하게 제어하여 다른 액션과 연동할 때 이벤트를 활용합니다.

```yaml
alias: "SIP: 수신 시 수동 흐름 (이벤트 대기)"
trigger:
  - platform: event
    event_type: sip_incoming_call
action:
  - service: sip.answer
    target:
      entity_id: media_player.sip_client
  # 통화 연결 대기
  - wait_for_trigger:
      - platform: event
        event_type: sip_call_connected
    timeout: "00:00:10"
  # 안내 문구 읽기
  - service: tts.speak
    target:
      entity_id: tts.google_translate
    data:
      media_player_entity_id: media_player.sip_client
      message: "안녕하세요. 관리실에서 안내 말씀 드립니다."
  # 안내 완료까지 끊김 방지 대기
  - wait_for_trigger:
      - platform: event
        event_type: sip_playback_done
    timeout: "00:00:30"
  # 전화 끊기
  - service: sip.hangup
    target:
      entity_id: media_player.sip_client
```

#### 전화 발신 후 상대가 전화를 받으면 TTS 재생 후 끊기 (멀티스텝)
```yaml
alias: "SIP: 발신 후 TTS 안내 및 자동 종료 (멀티스텝)"
action:
  - service: sip.dial
    target:
      entity_id: media_player.sip_client
    data:
      number: "sip:<TARGET_EXT>@<FREEPBX_IP>"
      ring_timeout: 30
  # 상대방이 전화를 받을 때까지 대기
  - wait_for_trigger:
      - platform: event
        event_type: sip_call_connected
    timeout: "00:00:35"
  # 안내 문구 재생 (TTS)
  - service: tts.speak
    target:
      entity_id: tts.google_translate
    data:
      media_player_entity_id: media_player.sip_client
      message: "택배가 보관함에 도착하였습니다."
  # 안내 방송 재생 완료 대기 (메시지 끊김 방지)
  - wait_for_trigger:
      - platform: event
        event_type: sip_playback_done
    timeout: "00:00:30"
  # 통화 종료
  - service: sip.hangup
    target:
      entity_id: media_player.sip_client
```

---

## 5. IVR 메뉴 엔진 상세 (YAML 설정 스키마)

`menu` 구성 요소를 통화 연결 시 호출하여 중첩 키패드 선택 흐름을 설계할 수 있습니다. 

### `tts` 구성 블록
각 메뉴 및 분기 선택값(`choices`) 내부에는 `tts` 전용 블록을 정의하여 개별 TTS 설정을 지정할 수 있습니다.
- `message` (또는 `text`): TTS로 읽어줄 문장
- `engine` (또는 `tts_engine`): TTS 엔진 엔티티 ID (예: `tts.google_translate`, `tts.piper`)
- `language` (또는 `lang`): 언어 코드 (예: `ko`, `en`)
- `options` (또는 `tts_options`): 목소리 캐릭터 등 세부 설정 딕셔너리
- `handle_as_template`: `true` 설정 시 Jinja 템플릿 사용 가능

### IVR 작동 예시
```yaml
service: sip.answer
target:
  entity_id: media_player.sip_client
data:
  menu:
    id: root
    tts:
      message: "안녕하세요. 스마트홈 ARS입니다. 전등 제어는 1번, 보이스 어시스트 연결은 2번을 눌러주세요."
      engine: tts.google_translate
      language: ko
    wait_for_audio_to_finish: true
    timeout: 10
    choices_are_pin: false
    choices:
      "1":
        action:
          domain: light
          service: toggle
          entity_id: light.living_room_light
        tts:
          message: "거실 전등 상태를 전환합니다."
          engine: tts.google_translate
          language: ko
        post_action: hangup
      "2":
        action:
          domain: assist_pipeline
        post_action: noop
      "default":
        tts:
          message: "잘못된 번호입니다. 다시 확인해 주세요."
          engine: tts.google_translate
          language: ko
        post_action: repeat_message
      "timeout":
        post_action: hangup
```

---

## 6. 주소록 (Contacts) 및 자동 응답 (인터콤)

### `sip_contacts.json` 구성
수신 전화의 발신자 번호를 친근한 이름으로 변경하거나, 문 열림 등 자동 응답 동작 여부를 구성할 수 있습니다. HA 설정 폴더 (`/config/` 또는 `/homeassistant/`)에 `sip_contacts.json` 파일을 생성합니다.

```json
{
  "1001": "아빠",
  "1002": "엄마",
  "1003": {
    "name": "현관 인터폰",
    "auto_answer": true
  }
}
```
* 주소록에 매핑된 이름은 마지막 발신자 센서 속성이나 수신 이벤트(`sip_incoming_call`)의 `caller_name` 속성에 활용됩니다.

### 자동 응답 (Auto-Answer) 모드
인터콤이나 초인종 장치와 연결 시 유용합니다. 다음 중 하나가 감지되면 대기 링 벨 없이 즉시 통화 연결을 수행합니다:
1. **글로벌 토글**: 자동 응답 스위치(`switch.sip_client_auto_answer`)가 켜져(ON) 있을 때.
2. **SIP 헤더**: 수신 호의 SIP 헤더에 `Call-Info: ...; answer-after=0` 또는 `Alert-Info: Ring Answer` 등이 포함되어 올 때.
3. **주소록 설정**: `sip_contacts.json` 주소록 파일에서 발신자의 설정이 `"auto_answer": true`로 지정되어 있을 때.

---

## 7. 대시보드 및 고급 자동화 예시

### 인터폰 도어락 오픈 버튼 대시보드 구성 (DTMF)
현관 도어폰과 연결되어 있을 때 대시보드에서 도어락 해제 신호(예: `1` 또는 `*`)를 보낼 수 있는 대시보드 카드 구성 예제입니다. 통화가 연결되었을 때만 노출되도록 조건부 카드로 감싸는 것을 권장합니다.

```yaml
type: conditional
conditions:
  - condition: state
    entity: binary_sensor.sip_client_active
    state: "on"
card:
  type: button
  name: 현관문 열기
  icon: mdi:door-open
  tap_action:
    action: call-service
    service: sip.send_dtmf
    target:
      entity_id: media_player.sip_client
    data:
      digits: "1" # 로비폰 인터폰에서 기대하는 잠금해제 DTMF 번호
```

### 대시보드: 최근 통화 목록 카드 (Markdown Card)
최근 발신/수신 및 미응답 등의 통화 이력을 20개까지 대시보드 테이블 형태로 노출할 수 있습니다. `sensor.sip_client_last_call` 센서의 `call_history` 속성을 활용합니다.

```yaml
type: markdown
title: "📞 최근 통화 목록"
content: >
  <table style="width: 100%; border-collapse: collapse;">
    <thead>
      <tr style="border-bottom: 2px solid var(--divider-color); text-align: left;">
        <th style="padding: 8px;">시간</th>
        <th style="padding: 8px;">발신자</th>
        <th style="padding: 8px;">유형</th>
        <th style="padding: 8px; text-align: right;">통화시간</th>
      </tr>
    </thead>
    <tbody>
      {% set history = state_attr('sensor.sip_client_last_call', 'call_history') %}
      {% if history %}
        {% for call in history %}
          <tr style="border-bottom: 1px solid var(--divider-color);">
            <td style="padding: 8px; font-size: 0.9em; color: var(--secondary-text-color);">
              {{ as_timestamp(call.timestamp) | timestamp_custom('%m/%d %H:%M') }}
            </td>
            <td style="padding: 8px;">
              <b>{{ call.name }}</b> <span style="font-size: 0.8em; color: var(--secondary-text-color);">({{ call.number }})</span>
            </td>
            <td style="padding: 8px; font-size: 0.9em;">
              {% if call.direction == 'incoming' %}
                {% if call.status == 'answered' %}
                  <span style="color: var(--success-color);">🟢 ↙️ 수신완료</span>
                {% elif call.status == 'rejected' %}
                  <span style="color: var(--error-color);">🔴 🚫 거절됨</span>
                {% else %}
                  <span style="color: var(--warning-color);">orange ↙️ 부재중</span>
                {% endif %}
              {% else %}
                {% if call.status == 'answered' %}
                  <span style="color: var(--info-color);">🔵 ↗️ 발신완료</span>
                {% else %}
                  <span style="color: var(--secondary-text-color);">⚪ ↗️ 연결안됨</span>
                {% endif %}
              {% endif %}
            </td>
            <td style="padding: 8px; text-align: right; font-size: 0.9em;">
              {% if call.duration > 0 %}
                {{ call.duration }}초
              {% else %}
                -
              {% endif %}
            </td>
          </tr>
        {% endfor %}
      {% else %}
        <tr>
          <td colspan="4" style="padding: 16px; text-align: center; color: var(--secondary-text-color);">
            통화 기록이 없습니다.
          </td>
        </tr>
      {% endif %}
    </tbody>
  </table>
```

### 보이스 어시스트(Voice Assist) 연결 자동화
통화 연결 즉시 HA 음성 가상 비서 파이프라인과 양방향 오디오를 연결하여 대화합니다.
```yaml
alias: "SIP: 보이스 어시스트 자동 양방향 연결"
trigger:
  - platform: state
    entity_id: binary_sensor.sip_client_active
    to: "on"
action:
  - service: sip.answer
    target:
      entity_id: media_player.sip_client
  - service: sip.start_assist
    target:
      entity_id: media_player.sip_client
```

---

## 8. 이벤트 명세 (HA Event Bus & Event Entity)

`hass-sip`는 자동화 작성이 간편하도록 **이벤트 엔티티** (`event.sip_client_call_events`)를 기본 제공하며, 기존 방식의 raw 이벤트 구독도 지원합니다.

### 1. 통화 이벤트 엔티티 (자동화 권장)
각 SIP 기기별로 생성되는 `event.sip_client_call_events` 엔티티를 사용하여 UI 자동화 편집기에서 간편하게 트리거를 정의할 수 있습니다.

* 지원되는 `event_type` 속성값:
  - `incoming`: 수신 전화 수신 시 (속성: `caller`, `caller_name`)
  - `connected`: 전화 연결 완료 시
  - `playback_done`: TTS/안내 방송 전송 완료 시
  - `ended`: 통화 종료 시
  - `dtmf`: 키패드 숫자 수신 시 (속성: `digit`)
  - `recording_started` / `recording_stopped`: 녹음 시작/중지 시
  - `registered`: SIP 등록 성공 시

### 2. 로우 이벤트 (HA Event Bus)

| 이벤트명 | 추가 정보 (Payload) | 실행 시점 |
|:---|:---|:---|
| `sip_registered` | 없음 | SIP 등록 성공 시 |
| `sip_state_changed` | `state` (`idle`, `registering`, `registered`, `inviting`, `ringing_out`, `incoming`, `answering`, `in_call`) | SIP 제어기 상태 변경 시 |
| `sip_incoming_call` | `caller`, `caller_name` | 수신 전화 도착 시 |
| `sip_call_connected` | 없음 | 전화 쌍방 연결 및 오디오 활성화 시 |
| `sip_playback_done` | 없음 | TTS 및 미디어 재생 전송 완료 시 |
| `sip_call_ended` | 없음 | 상대 또는 본인 통화 종료 시 |
| `sip_dtmf_digit` | `digit` | 상대가 키패드 숫자를 입력했을 때 |
| `sip_recording_started` | `recording_file` | 녹음 파일 저장 시작 시 |
| `sip_recording_stopped` | 없음 | 녹음 저장 중단 시 |

---

## 9. 문제 해결 (Troubleshooting)

- **SIP 등록 실패**: FreePBX 내선 비밀번호와 HA UI 설정상의 ID/Password가 일치하는지 확인하십시오. FreePBX Fail2Ban 기능 등으로 인해 HA IP가 차단되었는지 확인하십시오.
- **오디오 끊김 / 단방향 통화**: 방화벽 내 NAT 포트 포워딩 문제일 수 있습니다. Local RTP 포트(기본 `7078`) 및 FreePBX RTP 포트 대역(UDP `10000–20000`)이 제대로 오픈되었는지 확인하십시오.
- **FFmpeg 오동작**: 리샘플링 및 변환에 `ffmpeg` 바이너리가 사용됩니다. 홈어시스턴트 호스트 시스템 환경에 `ffmpeg`가 설치되어 접근 가능한 상태인지 확인하십시오.
