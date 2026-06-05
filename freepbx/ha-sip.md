# Home Assistant ha-sip ↔ FreePBX

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

문서: [ha-plugins README](https://github.com/arnonym/ha-plugins/blob/main/README.md)

## 3. ha-sip 애드온 구성 (YAML)

`<FREEPBX_IP>`, `<HA_SIP_EXT>`, `<FREEPBX_EXTENSION_SECRET>`을 실제 값으로 바꿉니다.

```yaml
sip_global:
  port: 5060
  log_level: 5
  name_server: ""
  cache_dir: "/config/audio_cache"
  global_options: ""

sip:
  enabled: true
  registrar_uri: "sip:<FREEPBX_IP>"
  id_uri: "sip:<HA_SIP_EXT>@<FREEPBX_IP>"
  realm: "*"
  user_name: "<HA_SIP_EXT>"
  password: "<FREEPBX_EXTENSION_SECRET>"
  answer_mode: listen
  settle_time: 1
  incoming_call_file: ""
  options: ""

sip_2:
  enabled: false

tts:
  engine_id: "tts.edge_tts"
  platform: ""
  language: "ko-KR"
  voice: "ko-KR-SunHiNeural"
  debug_print: false

webhook:
  id: "<WEBHOOK_ID>"
```

### TTS 필드

| 필드 | 값 | 비고 |
|------|-----|------|
| `engine_id` | `tts.edge_tts` | HA에 설치된 Edge TTS 엔티티 ID (다르면 상태 화면에서 확인) |
| `platform` | `""` | **`engine_id` 사용 시 비움** |
| `language` | `ko-KR` | |
| `voice` | `ko-KR-SunHiNeural` | 다른 Neural 목소리 가능 |
| `debug_print` | `true` → 확인 후 `false` | 시작 시 로그에 엔진·언어 목록 |

목소리 ID만 쓰는 경우 `language: "ko-KR-SunHiNeural"`, `voice: ""` 로 시도할 수 있습니다.

### `answer_mode`

| 값 | 동작 |
|----|------|
| `listen` | 수신 시 **웹훅**만 (전화 안 받음) → HA 자동화 |
| `accept` | `incoming_call_file` 메뉴로 **자동 응답**·PIN·DTMF |

수신 메뉴 예: `/config/sip-incoming.yaml` — [README Incoming calls](https://github.com/arnonym/ha-plugins#incoming-calls)

## 4. 발신 — 다른 내선으로 전화 + TTS

**설정 → 애드온 → ha-sip → 정보**의 슬러그를 `addon:`에 사용 (설치마다 다름, 예: `c7744bff_ha-sip`).

자동화 **YAML 모드**:

```yaml
service: hassio.addon_stdin
data:
  addon: <HA_SIP_ADDON_SLUG>
  input:
    command: dial
    number: "sip:<TARGET_EXT>@<FREEPBX_IP>"
    sip_account: 1
    menu:
      message: "안내 메시지입니다."
      language: ko-KR-SunHiNeural
      post_action: hangup
```

통화 중 TTS만:

```yaml
    command: play_message
    number: "sip:<TARGET_EXT>@<FREEPBX_IP>"
    message: "안내 메시지입니다."
    tts_language: ko-KR-SunHiNeural
    cache_audio: true
    wait_for_audio_to_finish: true
    post_action: hangup
```

## 5. 수신 — 전화로 HA 자동화 (요약)

1. `webhook.id`와 동일 ID로 **자동화 → 트리거 → Webhook**
2. `listen` 모드: `trigger.json.parsed_caller`, `trigger.json.event == "incoming_call"` 등
3. 응답·TTS: `command: answer`, `internal_id: "{{ trigger.json.internal_id }}"`

상세: [Web-hooks](https://github.com/arnonym/ha-plugins#web-hooks)

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
| AMI와 혼동 | 5038 Manager ≠ 5060 Extension — [ha-asterisk.md](ha-asterisk.md) |

## 8. 보안

- Extension Secret·웹훅 URL·토큰은 **커밋하지 않음**
- `accept` + PIN 메뉴 시 `allowed_numbers` 제한 권장
- SIP·AMI 포트를 인터넷에 포워딩하지 않음 (LAN 내부)
