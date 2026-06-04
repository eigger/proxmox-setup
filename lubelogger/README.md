# LubeLogger

[LubeLogger](https://lubelogger.com) — 차량 정비·연비 기록 웹 앱. Proxmox VM/LXC 또는 Docker로 셀프호스팅할 때 참고용 설정·번역 자료를 이 폴더에 둡니다.

## 폴더 구조

```
lubelogger/
├── README.md
├── ha-rest-command.md       # Home Assistant REST Command 연동
├── ha-fuel-opinet.md        # 주유 등록 (오피넷 API + LubeLogger)
└── translations/
    └── Asia/
        └── ko_KR.json         # 한국어 번역
```

`translations/` 레이아웃은 공식 번역 저장소 [hargata/lubelog_translations](https://github.com/hargata/lubelog_translations)와 동일합니다. PR 제출 시 `Asia/ko_KR.json`을 그대로 복사하면 됩니다.

## 한국어 번역

`translations/Asia/ko_KR.json`에 한국어 번역본이 있습니다. 수정 시 **키(key)** 는 변경하지 않고 **값(value)** 만 편집합니다.

- LubeLogger UI **Translation Editor**로 편집·내보내기 가능  
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

## 설치 (요약)

공식 문서: [docs.lubelogger.com](https://docs.lubelogger.com/)

Docker 예시:

```bash
docker run -d --name lubelogger \
  -p 8080:8080 \
  -v /path/to/lubelogger/data:/App/data \
  -v /path/to/lubelogger/config:/App/config \
  ghcr.io/hargata/lubelog:latest
```

Proxmox LXC/VM 사양·백업은 환경에 맞게 추가 문서를 이 폴더에 작성하면 됩니다.

## 연동 가이드

| 주제 | 문서 |
|------|------|
| Home Assistant REST Command (주행거리·주유 기록) | [ha-rest-command.md](ha-rest-command.md) |
| OBD → LubeLogger 주행거리 자동 등록 | [ha-rest-command.md §4](ha-rest-command.md#4-obd-연동--시동-off-시-주행거리-등록) ([espcomponents/colorado](https://github.com/eigger/espcomponents/tree/master/packages/display/colorado)) |
| 주유 등록 — 오피넷 API 키 | [ha-fuel-opinet.md §1](ha-fuel-opinet.md#1-오피넷-api-키-발급) |
| 주유 등록 — 주유소 단가 REST 센서 | [ha-fuel-opinet.md §3](ha-fuel-opinet.md#3-주유소-단가-rest-센서) |
| 주유 등록 — 금액 기반 스크립트 | [ha-fuel-opinet.md §4](ha-fuel-opinet.md#4-금액-기반-주유-스크립트) |
| 주유 등록 — 대시보드 카드 | [ha-fuel-opinet.md §5](ha-fuel-opinet.md#5-주유-대시보드-카드) |

## 비밀값

SMTP, OIDC, API 키 등은 **커밋하지 않습니다**.
