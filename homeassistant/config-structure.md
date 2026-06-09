# Home Assistant — 설정 구조 (packages)

**Language:** [한국어](config-structure.md) · [English](config-structure.en.md)

HA 인스턴스의 `/config`는 **`packages/` 폴더**로 기능별 YAML을 나눕니다. `configuration.yaml`은 최소한만 두고, REST Command·자동화·스크립트 등은 패키지 파일에 추가합니다.

공식: [Packages](https://www.home-assistant.io/docs/configuration/packages/)

## 문서 계층 (이 저장소)

| 층 | 경로 | 역할 |
|----|------|------|
| **LXC/VM README** | `lubelogger/README.md`, `traccar/README.md` … | community-scripts 설치, 포트, HA **링크** |
| **연동 상세** | `*/ha-*.md`, `cloudflared/tunnel-setup.md` | API·자동화·Webhook·LXC↔HA 흐름 |
| **packages** | `homeassistant/packages/*.yaml` | HA에 복사할 **YAML 단일 출처** |

- LXC README에 YAML 전체를 **중복하지 않습니다**.
- `ha-*.md`에도 packages와 동일한 YAML 블록을 **두지 않고** packages 링크로 대체합니다.
- 자동화·스크립트·애드온 설정은 아직 packages에 없을 수 있으며, 해당 `ha-*.md`에만 둡니다.

## 작성 톤 (통일 규칙)

| 문서 종류 | 서두 | 필수 섹션 |
|-----------|------|-----------|
| **LXC/VM README** | `[제품](URL) — 역할 한 줄.` | `## 설치` → `## Home Assistant 연동`(해당 시) → `## 폴더 구조` → `## 비밀값` |
| **packages/*.md** | 기능 한 줄 + `HA 경로: /config/packages/...` | `## 사전 조건` → 본문 → `## 연동`(선택) → `## 적용` |
| **ha-*.md** | 기능 한 줄 + README·packages 링크 | `## 환경 (플레이스홀더)` → `## 1.` … → 문제 해결·보안 |

- **플레이스홀더:** `<LUBELOGGER_IP>` 형식 (대문자 스네이크)
- **표:** 단순 2~3열, `:---` 정렬 행 사용 안 함
- **문체:** 기술 설명체. 구어·감탄·튜토리얼 톤 지양
- **YAML:** packages에 있는 설정은 `ha-*.md`에 중복하지 않고 링크로 대체
- **내부 링크:** 앵커 URL (`#섹션`) 사용. `§` 표기는 지양

## 다국어 (i18n)

- **한국어:** `README.md`, `ha-*.md` 등 기본 파일명
- **English:** 같은 경로에 `*.en.md` (예: `README.en.md`, `ha-rest-command.en.md`)
- **YAML:** `homeassistant/packages/*.yaml`은 **언어 공통 단일 출처** — `.en.md`로 복제하지 않음
- 각 문서 H1 아래 **Language** 링크로 한·영 전환

## configuration.yaml (최소)

```yaml
homeassistant:
  packages: !include_dir_named packages
```

`!include_dir_named` — `packages/` 아래 **파일명(확장자 제외)** 이 패키지 이름이 됩니다.  
예: `packages/lubelogger.yaml` → 패키지 키 `lubelogger`

## HA 인스턴스 디렉터리

```
/config/
├── configuration.yaml       # packages 한 줄 (+ default_config 등 최소 항목)
├── secrets.yaml             # 비밀값 (git 제외)
└── packages/
    ├── lubelogger.yaml      # LubeLogger REST·자동화
    ├── traccar.yaml         # Traccar REST·자동화
    ├── http.yaml            # trusted_proxies (Tunnel·프록시)
    ├── tasmota.yaml         # Athom IR Remote MQTT
    ├── tmap.yaml            # SK TMAP 경로안내
    ├── wol.yaml             # Wake-on-LAN
    ├── recorder.yaml        # Recorder·외부 DB
    └── …
```

설정 변경 후 **개발자 도구 → YAML 구성 확인** 또는 재시작으로 반영합니다.

## 패키지 파일 예시

파일 하나에 해당 주제의 `rest_command`, `automation`, `script`, `rest` 등을 묶습니다.

`rest_command`·`rest` 등 **짧은 통합 설정**은 [packages/](packages/)에 파일별로 둡니다. OBD 자동화처럼 긴 시나리오는 [lubelogger/ha-rest-command.md](../lubelogger/ha-rest-command.md) 등 **서비스 문서**에 두고, 필요 시 나중에 같은 패키지 파일에 `automation:`·`script:`를 추가할 수 있습니다.

### 패키지에 넣을 수 있는 키 (예)

| 키 | 용도 |
|----|------|
| `rest_command` | LubeLogger, Traccar API |
| `rest` | 오피넷 단가 센서 |
| `mqtt` | Tasmota IR 센서·버튼 |
| `switch` | Wake-on-LAN |
| `recorder` | 히스토리 DB·purge |
| `automation` | 위치·주유·라벨 인쇄 등 |
| `script` | grocy 금액 기반 주유 |
| `http` | `trusted_proxies` (Cloudflared) |

## 이 저장소 ↔ HA `/config`

| HA `packages/` | 이 repo | 연동 문서 |
|----------------|---------|-----------|
| `http.yaml` | [packages/http.yaml](packages/http.yaml) | [cloudflared/](../cloudflared/tunnel-setup.md) |
| `lubelogger.yaml` | [packages/lubelogger.yaml](packages/lubelogger.yaml) | [lubelogger/ha-rest-command.md](../lubelogger/ha-rest-command.md) |
| `tasmota.yaml` | [packages/tasmota.yaml](packages/tasmota.yaml) | [packages/tasmota.md](packages/tasmota.md) |
| `tmap.yaml` | [packages/tmap.yaml](packages/tmap.yaml) | [packages/tmap.md](packages/tmap.md) |
| `traccar.yaml` | [packages/traccar.yaml](packages/traccar.yaml) | [traccar/ha-rest-command.md](../traccar/ha-rest-command.md) |
| `wol.yaml` | [packages/wol.yaml](packages/wol.yaml) | [packages/wol.md](packages/wol.md) |
| `recorder.yaml` | [packages/recorder.yaml](packages/recorder.yaml) | [packages/recorder.md](packages/recorder.md) |
서비스별 **상세 YAML·설명**은 각 앱 폴더(`lubelogger/`, `traccar/` …)에 두고, `homeassistant/packages/`에는 HA에 넣을 **조합본·스니펫**을 정리합니다.

## secrets.yaml

비밀값만 분리합니다. 패키지 YAML에서는 `!secret`로 참조합니다.

```yaml
lubelogger_username: "<LUBELOGGER_USER>"
lubelogger_password: "<LUBELOGGER_PASSWORD>"
tmap_api_key: "<TMAP_APP_KEY>"
recorder_db_url: "mysql://<USER>:<PASS>@<DB_HOST>:3306/homeassistant?charset=utf8mb4"
```

**git에 커밋하지 않습니다.**

## 추가 예정

- LubeLogger·Traccar 자동화·스크립트 packages 통합
- File Editor / Studio Code Server로 `/config` 동기화·백업 방법 (필요 시)
