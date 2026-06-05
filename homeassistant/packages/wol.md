# packages/wol.yaml

NAS 등 장치를 [Wake-on-LAN](https://www.home-assistant.io/integrations/wake_on_lan/) 매직 패킷으로 원격 기동합니다.

HA 경로: `/config/packages/wol.yaml`

## 사전 조건

- 대상 장치 BIOS/펌웨어에서 **Wake-on-LAN** 활성화
- HA와 NAS가 같은 LAN(또는 브로드캐스트 전달 가능한 네트워크)

## 설정

`wol.yaml`의 `<NAS_MAC>`를 대상 장치 MAC으로 바꿉니다.

```yaml
switch:
  - platform: wake_on_lan
    name: NAS Wake on lan
    mac: "<NAS_MAC>"
```

| 항목 | 설명 |
|------|------|
| `name` | HA UI 표시 이름 → entity_id 예: `switch.nas_wake_on_lan` |
| `mac` | WoL 대상 MAC (`XX:XX:XX:XX:XX:XX`) |

서브넷 브로드캐스트가 필요하면 [공식 문서](https://www.home-assistant.io/integrations/wake_on_lan/)의 `broadcast_address`·`broadcast_port`를 추가합니다.

## 사용

- 대시보드에서 **NAS Wake on lan** 스위치 ON
- 자동화: `service: switch.turn_on` · `entity_id: switch.nas_wake_on_lan`

## 적용

1. `packages/wol.yaml` 배치 후 MAC 수정
2. **개발자 도구 → YAML** 구성 확인
