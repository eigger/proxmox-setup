# packages/tasmota.yaml

[Athom Tasmota IR Remote](https://www.athom.tech/) (AR01)로 수신한 IR 코드를 MQTT 센서로 보고, 선풍기 등 IR 버튼을 HA에서 제어합니다.

HA 경로: `/config/packages/tasmota.yaml`

## 사전 조건

1. HA **MQTT** 통합 구성 (Mosquitto add-on 또는 외부 브로커)
2. Tasmota **Topic** = `tasmota_ir` (Console → `Topic tasmota_ir` 또는 Web UI)
3. Tasmota에서 IR 수신 로그: `SetOption60 1` (JSON `IrReceived` on `tele/.../RESULT`)

토픽 접두사가 다르면 YAML 전체의 `tasmota_ir`를 실제 Topic으로 바꿉니다.

## MQTT 토픽

| 토픽 | 용도 |
|------|------|
| `tele/tasmota_ir/LWT` | 온라인 여부 |
| `tele/tasmota_ir/RESULT` | IR 수신 (`IrReceived`) |
| `cmnd/tasmota_ir/irsend` | IR 송신 |

## 활성 엔티티

| 장치 | 엔티티 | 설명 |
|------|--------|------|
| Athom IR | `sensor.tasmota_ir_controller_irreceived` | 수신 IR `Data` |
| Balmuda GreenFan S | `button.greenfans_*` ×4 | OnOff, Rotate, Speed, Timer |
| Hanil BBF-BL12W | `button.hanil_fan_*` ×8 | OnOff, Mode, Speed±, Rotate, Timer±, Mute |

IR 코드 학습: 리모컨으로 신호 보낸 뒤 `sensor..._irreceived` 속성에서 Protocol·Data 확인.

## 적용

1. MQTT 통합·Tasmota Topic 확인
2. `packages/tasmota.yaml` 배치
3. **개발자 도구 → YAML** 구성 확인
4. 대시보드에 `button`·`sensor` 추가
