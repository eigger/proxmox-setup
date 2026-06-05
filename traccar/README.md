# Traccar

**Language:** [한국어](README.md) · [English](README.en.md)

[Traccar](https://www.traccar.org/) — GPS 추적 서버. Proxmox VM/LXC 또는 Docker로 셀프호스팅하고 Home Assistant 등에서 위치·텔레메트리를 전송할 때 참고합니다.

## 설치

Proxmox VE **LXC** 설치 스크립트: [Traccar — Proxmox VE Helper Scripts](https://community-scripts.org/scripts/traccar)

1. Proxmox 호스트 **Shell**에서 아래 명령 실행
2. 마법사에서 **Default** 또는 **Advanced** 선택 후 LXC 생성

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/traccar.sh)"
```

설치 후 웹 UI: `http://<TRACCAR_IP>:8082` (기본 포트 **8082**)  
HA 연동(OsmAnd HTTP): 포트 **5055**

기본 DB는 내장 H2입니다. 운영용 **MariaDB/MySQL 전환**·**H2 데이터 마이그레이션**·**주기적 DB 정리**는 [mariadb.md](mariadb.md)를 참고하세요.

## Home Assistant 연동

| packages (`/config/packages/`) | 설명 |
|----------------------------------|------|
| [traccar.yaml](../homeassistant/packages/traccar.yaml) | `send_to_traccar` REST Command |

| 연동 가이드 | 문서 |
|-------------|------|
| REST Command·변수·호출 예시 | [ha-rest-command.md](ha-rest-command.md) |
| GPS + OBD 위치 자동화 | [ha-rest-command.md](ha-rest-command.md#41-gps--obd) |
| GPS만 위치 자동화 | [ha-rest-command.md](ha-rest-command.md#42-gps만-obd-없음) |
| HA packages·secrets 구조 | [homeassistant/config-structure.md](../homeassistant/config-structure.md) |

| 운영 | 문서 |
|------|------|
| MariaDB/MySQL 전환 · H2 마이그레이션 · GPS DB 정리 · 서버 로그 정리 | [mariadb.md](mariadb.md) |

## 폴더 구조

```
traccar/
├── README.md
├── mariadb.md               # MariaDB/MySQL · H2 마이그레이션 · cron
└── ha-rest-command.md       # HA 연동 상세 (자동화·OBD)
```

HA packages: [traccar.yaml](../homeassistant/packages/traccar.yaml)

## 비밀값

Traccar 서버 주소·디바이스 ID는 환경에 따라 `secrets.yaml`에 두고 **커밋하지 않습니다**.
