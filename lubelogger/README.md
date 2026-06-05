# LubeLogger

**Language:** [한국어](README.md) · [English](README.en.md)

[LubeLogger](https://lubelogger.com) — 차량 정비·연비 기록 웹 앱. Proxmox VM/LXC 또는 Docker로 셀프호스팅할 때 참고용 설정·번역 자료를 이 폴더에 둡니다.

## 설치

Proxmox VE **LXC** 설치 스크립트: [LubeLogger — Proxmox VE Helper Scripts](https://community-scripts.org/scripts/lubelogger)

1. Proxmox 호스트 **Shell**에서 아래 명령 실행
2. 마법사에서 **Default** 또는 **Advanced** 선택 후 LXC 생성

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/lubelogger.sh)"
```

설치 후 웹 UI: `http://<LUBELOGGER_IP>:5000` (기본 포트 **5000**)

## Home Assistant 연동

| packages (`/config/packages/`) | 설명 |
|----------------------------------|------|
| [lubelogger.yaml](../homeassistant/packages/lubelogger.yaml) | REST Command (주행거리·주유) |
| [opinet.yaml](../homeassistant/packages/opinet.yaml) | 오피넷 주유소 단가 REST 센서 |

| 연동 가이드 | 문서 |
|-------------|------|
| REST Command·OBD 주행거리 자동화 | [ha-rest-command.md](ha-rest-command.md) |
| 주유 (오피넷 API·스크립트·대시보드) | [ha-fuel-opinet.md](ha-fuel-opinet.md) |
| HA packages·secrets 구조 | [homeassistant/config-structure.md](../homeassistant/config-structure.md) |

## 폴더 구조

```
lubelogger/
├── README.md
├── ha-rest-command.md       # HA 연동 상세 (자동화·OBD)
├── ha-fuel-opinet.md        # 주유 연동 상세 (오피넷·스크립트)
└── translations/
    └── Asia/
        └── ko_KR.json         # 한국어 번역
```

HA packages: [lubelogger.yaml](../homeassistant/packages/lubelogger.yaml), [opinet.yaml](../homeassistant/packages/opinet.yaml)

`translations/` 레이아웃은 공식 번역 저장소 [hargata/lubelog_translations](https://github.com/hargata/lubelog_translations)와 동일합니다. PR 제출 시 `Asia/ko_KR.json`을 그대로 복사하면 됩니다.

## 한국어 번역

`translations/Asia/ko_KR.json`에 한국어 번역본이 있습니다. 수정 시 **키(key)** 는 변경하지 않고 **값(value)** 만 편집합니다.

- LubeLogger UI **Translation Editor**로 편집·보내기 가능  
- 문서: [Translations – LubeLogger Wiki](https://docs.lubelogger.com/Misc/Translations)

### 참고

| 항목 | 설명 |
|------|------|
| 파일명 | ISO 639-1 + 지역: `ko_KR.json` |
| 지역 폴더 | 한국 → `Asia/` |
| 영문 원본 | [lubelog/wwwroot/defaults/en_US.json](https://github.com/hargata/lubelog/blob/main/wwwroot/defaults/en_US.json) |
| 공식 번역 PR | [lubelog_translations](https://github.com/hargata/lubelog_translations) (병합 시 승인 3명 필요) |
| 번역 미적용 UI | About, SweetAlert 확인창, 우측 상단 Toast 등 |

### 인스턴스에 적용

1. LubeLogger **Settings → Manage Languages → Upload** 에서 `ko_KR.json` 업로드  
2. 또는 **Get Translations** 로 공식 저장소에서 받은 뒤, 커스텀 파일로 교체

## 비밀값

SMTP, OIDC, API 키 등은 **커밋하지 않습니다**.
