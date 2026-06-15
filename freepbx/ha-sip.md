# Home Assistant ha-sip ↔ FreePBX

**Language:** [한국어](ha-sip.md) · [English](ha-sip.en.md)

> [!NOTE]
> 이 설정은 이제 필수가 아닌 **선택 사항(Nice-to-have)**입니다. 
> 대신 네이티브 미디어 플레이어 형태로 간편하게 연동할 수 있는 [ha-hass-sip.md (SIP Client HACS 통합)](ha-hass-sip.md) 방식을 메인으로 사용하는 것을 권장합니다.

[arnonym/ha-plugins](https://github.com/arnonym/ha-plugins)의 **ha-sip** 애드온으로 HA가 FreePBX에 **SIP 클라이언트**로 등록합니다. TTS는 HA **Edge TTS**(`tts.edge_tts`)를 사용합니다.

LXC 설치·포트: [README.md](README.md) · `homeassistant/packages/` 조합본 없음 (애드온 설정은 [3. ha-sip 애드온 구성](#3-ha-sip-애드온-구성-yaml))

### 참고

[TECH7Fox Asterisk 애드온](https://github.com/TECH7Fox/asterisk-hass-addons) / [SIP-HASS](https://tech7fox.github.io/sip-hass-docs/)와는 별개 프로젝트입니다.

## AMI 통합과의 차이

| | [ha-asterisk.md](ha-asterisk.md) (AMI) | ha-sip (이 문서) |
|--|--------------------------------------|------------------|
| 연결 | TCP **5038** Manager | UDP/TCP **5060** SIP |
| FreePBX 계정 | Asterisk Manager User | **PJSIP Extension** |
| HA 역할 | PBX 원격 제어 | **전화기처럼 등록** |
| TTS | PBX `Playback` / 파일 | **HA Edge TTS** 직접 합성 |
| 자동화 | `asterisk.send_action` | `hassio.addon_stdin` + Webhook |

둘 다 FreePBX에 동시에 사용 가능합니다.

## 환경 (플레이스홀더)

| 항목 | 예시 | 설명 |
|------|------|------|
| FreePBX | `<FREEPBX_IP>` | PBX LAN 주소 |
| ha-sip 내선 | `<HA_SIP_EXT>` | HA 전용 Extension (예: `100`) |
| 아날로그/다른 내선 | `<TARGET_EXT>` | Grandstream 등 (예: `1001`) |

```
HA (ha-sip) ──SIP 5060──► FreePBX ──SIP──► Grandstream / 기타 내선
HA (AMI)    ──5038──────► FreePBX (자동화 Originate, 별도 문서)
```

## 1. FreePBX — ha-sip 전용 내선

1. **Applications → Extensions → Add PJSIP Extension**
2. **User Extension:** `<HA_SIP_EXT>` (Grandstream 내선과 **별도** 번호)
3. **Secret** 기록 → ha-sip `password`에만 사용 (저장소·git에 넣지 않음)
4. **Apply Config**
5. **Reports → Asterisk Info → PJSIP** 에서 해당 내선 **Registered** 확인 (ha-sip 애드온 시작 후)

## 2. HA — 애드온 설치

1. **설정 → 애드온 → 애드온 스토어** → 저장소: `https://github.com/arnonym/ha-plugins`
2. **ha-sip** 설치
3. 아래 구성 입력 후 **시작**
4. 애드온 **로그**에 SIP 등록 성공 메시지 확인

문서: [ha-plugins README](https://github.com/arnonym/ha-plugins/blob/main/README.md) · 스키마: [ha-sip/config.json](https://github.com/arnonym/ha-plugins/blob/main/ha-sip/config.json) (v5.5)

## 3. ha-sip 애드온 구성 (YAML)

`<FREEPBX_IP>`, `<HA_SIP_EXT>`, `<FREEPBX_EXTENSION_SECRET>`을 실제 값으로 바꿉니다. `user_name`·`password`가 숫자로 시작하면 `"100"`처럼 **따옴표**로 감쌉니다.

```yaml
sip_global:
  port: 5060
  log_level: 5
  name_server: ""
  cache_dir: /config/tts
  global_options: ""

sip:
  enabled: true
  registrar_uri: sip:<FREEPBX_IP>
  id_uri: sip:<HA_SIP_EXT>@<FREEPBX_IP>
  realm: "*"
  user_name: "<HA_SIP_EXT>"
  password: "<FREEPBX_EXTENSION_SECRET>"
  answer_mode: listen
  settle_time: 1
  incoming_call_file: ""
  options: ""

sip_2:
  enabled: false
  registrar_uri: sip:<OTHER_SIP_HOST>
  id_uri: sip:<OTHER_USER>@<OTHER_SIP_HOST>
  realm: "*"
  user_name: <OTHER_USER>
  password: <OTHER_SECRET>
  answer_mode: listen
  settle_time: 1
  incoming_call_file: ""
  options: ""

sip_3:
  enabled: false
  registrar_uri: sip:<OTHER_SIP_HOST>
  id_uri: ""
  realm: "*"
  user_name: ""
  password: ""
  answer_mode: listen
  settle_time: 1
  incoming_call_file: ""
  options: ""

tts:
  engine_id: tts.edge_tts_service_edge_tts
  platform: ""
  language: ko-KR
  voice: ko-KR-SunHiNeural
  debug_print: true

webhook:
  id: sip_call_webhook_id

sensors:
  enabled: false
  entity_prefix: ha_sip
```

`password`·`webhook.id`는 **git에 넣지 않습니다.** FreePBX만 쓰면 `sip`만 `enabled: true`, `sip_2`·`sip_3`는 `false`로 둡니다.

### 주요 필드

| 블록 | 필드 | 비고 |
|------|------|------|
| `sip_global` | `cache_dir` | TTS 캐시 디렉터리. **`/config` 또는 `/media` 아래에 미리 생성**해야 함 (없으면 애드온 로그에 `Cache directory not found`) |
| `sip` | `registrar_uri` / `id_uri` | FreePBX LAN IP·ha-sip 전용 내선 |
| `sip` | `answer_mode: listen` | 수신 → 웹훅만 ([§5](#5-수신--전화로-ha-자동화-요약)) |
| `tts` | `engine_id` | HA **설정 → 개발자 도구 → 상태**에서 `tts.` 엔티티 ID 확인. 예: `tts.edge_tts`, `tts.edge_tts_service_edge_tts` |
| `tts` | `platform` | `""` — **`engine_id` 사용 시 비움** |
| `tts` | `debug_print` | `true`로 TTS 확인 후 `false` |
| `webhook` | `id` | HA 자동화 Webhook 트리거 ID와 **동일** |
| `sensors` | `enabled` | SIP 상태 센서. 필요 없으면 `false` |

목소리 ID만 쓰는 경우 `language: ko-KR-SunHiNeural`, `voice: ""` 로 시도할 수 있습니다.

### `answer_mode`

| 값 | 동작 |
|----|------|
| `listen` | 수신 시 **웹훅**만 (전화 안 받음) → HA 자동화 |
| `accept` | `incoming_call_file` 메뉴로 **자동 응답**·PIN·DTMF |

수신 메뉴 예: `/config/sip-incoming.yaml` — [README Incoming calls](https://github.com/arnonym/ha-plugins#incoming-calls)

## 4. 발신 — 다른 내선으로 전화 + TTS

발신은 `hassio.addon_stdin`으로 애드온에 JSON을 보냅니다 ([command_handler.py](https://github.com/arnonym/ha-plugins/blob/main/ha-sip/src/command_handler.py) 기준).

**설정 → 애드온 → ha-sip → 정보**의 슬러그를 `addon:`에 사용 (설치마다 다름, 예: `ea162690_ha-sip`). 자동화는 **YAML 모드**로 편집합니다.

### `dial` — 전화 걸고 TTS 안내

`command: dial`이 인식하는 필드: `number`, `menu`, `sip_account`(1–3), `ring_timeout`(초, 기본 300), `webhook_to_call`(선택).

> **`post_action`·`wait_for_audio_to_finish`는 `input` 최상위가 아니라 `menu` 안에 둡니다.** (`dial`은 `menu`만 넘김)

| `menu` 필드 | 설명 |
|-------------|------|
| `message` | TTS로 읽을 문장 (`tts` 필드 없음) |
| `language` | (선택) 메뉴별 TTS 언어·목소리. 생략 시 [§3](#3-ha-sip-애드온-구성-yaml) `tts.language` / `voice` |
| `post_action` | `hangup` · `noop`(기본) · `repeat_message` · `return` · `jump <id>` |
| `wait_for_audio_to_finish` | `true` — 재생 끝날 때까지 DTMF 무시 |
| `cache_audio` | `true` — `cache_dir`에 TTS 캐시 (고정 문장만) |

```yaml
action: hassio.addon_stdin
data:
  addon: <HA_SIP_ADDON_SLUG>
  input:
    command: dial
    number: sip:<TARGET_EXT>@<FREEPBX_IP>
    sip_account: 1
    ring_timeout: 15
    menu:
      message: "안내 메시지입니다."
      post_action: hangup
      wait_for_audio_to_finish: true
```

`service: hassio.addon_stdin` 형식도 동일합니다. 같은 번호로 이미 통화 중이면 요청은 **무시**됩니다.

### `hangup` — 끊기

```yaml
action: hassio.addon_stdin
data:
  addon: <HA_SIP_ADDON_SLUG>
  input:
    command: hangup
    number: sip:<TARGET_EXT>@<FREEPBX_IP>
```

### `play_message` — 연결된 통화에 TTS만

이 명령만 `input` 최상위에 `wait_for_audio_to_finish`·`post_action`을 둡니다.

```yaml
action: hassio.addon_stdin
data:
  addon: <HA_SIP_ADDON_SLUG>
  input:
    command: play_message
    number: sip:<TARGET_EXT>@<FREEPBX_IP>
    message: "안내 메시지입니다."
    tts_language: ko-KR
    cache_audio: false
    wait_for_audio_to_finish: true
    post_action: hangup
```

`tts_language` 생략 시 애드온 `tts.language` 사용. DTMF·PIN 메뉴·`choices` 등은 [README Call menu](https://github.com/arnonym/ha-plugins#call-menu-definition) 참고.

## 5. 수신 — 전화로 HA 자동화 (요약)

`answer_mode: listen`이면 전화를 **받지 않고** `webhook.id`로 HA 자동화를 트리거합니다.

1. `webhook.id`와 동일 ID로 **자동화 → 트리거 → Webhook**
2. 수신 페이로드 예: `event: incoming_call`, `parsed_caller`, `internal_id` ([README](https://github.com/arnonym/ha-plugins#listen-mode))
3. 메뉴 ID 웹훅도 쓰면 `trigger.json.event == "incoming_call"` 로 분기

수신 후 응답·TTS (`number`는 **`internal_id`** — `caller` 아님):

```yaml
action: hassio.addon_stdin
data:
  addon: <HA_SIP_ADDON_SLUG>
  input:
    command: answer
    number: "{{ trigger.json.internal_id }}"
    menu:
      message: "안내 메시지입니다."
      post_action: hangup
```

`accept` 모드·PIN 메뉴: `incoming_call_file` — [README Incoming calls](https://github.com/arnonym/ha-plugins#incoming-calls)

## 6. 연결 확인

| 확인 | 방법 |
|------|------|
| SIP 등록 | FreePBX PJSIP에서 `<HA_SIP_EXT>` Registered |
| TTS | `debug_print: true` 후 애드올 로그 |
| 발신 | `dial` → `<TARGET_EXT>` 벨 울림 |
| 방화벽 | HA → FreePBX **5060**, RTP(10000–20000) |

## 7. 문제 해결

| 증상 | 조치 |
|------|------|
| 등록 안 됨 | Extension Secret·`<FREEPBX_IP>`·user_name 일치, Apply Config |
| TTS 실패 | `engine_id` 확인, `debug_print: true`, HA에서 `tts.speak` 테스트 |
| 통화 없음 | `number` 형식 `sip:<EXT>@<FREEPBX_IP>`, 슬러그·`sip_account: 1` |
| TTS 후 안 끊김 | `post_action: hangup`을 **`menu` 안**에 둠 (`dial`의 `input` 최상위는 무시됨) |
| TTS 캐시 오류 | `cache_dir` 디렉터리를 HA `/config` 아래에 **먼저 생성** |
| AMI와 혼동 | 5038 Manager ≠ 5060 Extension — [ha-asterisk.md](ha-asterisk.md) |

## 8. 보안

- Extension Secret·웹훅 URL·토큰은 **커밋하지 않음**
- `accept` + PIN 메뉴 시 `allowed_numbers` 제한 권장
- SIP·AMI 포트를 인터넷에 포워딩하지 않음 (LAN 내부)
