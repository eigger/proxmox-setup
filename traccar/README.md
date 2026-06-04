# Traccar

[Traccar](https://www.traccar.org/) — GPS 추적 서버. Proxmox VM/LXC 또는 Docker로 셀프호스팅하고 Home Assistant 등에서 위치·텔레메트리를 전송할 때 참고합니다.

## 폴더 구조

```
traccar/
├── README.md
└── ha-rest-command.md       # Home Assistant → Traccar (OsmAnd HTTP)
```

## 연동 가이드

| 주제 | 문서 |
|------|------|
| Home Assistant REST Command (위치·속도 등 전송) | [ha-rest-command.md](ha-rest-command.md) |
| GPS + OBD → Traccar 위치 자동화 | [ha-rest-command.md §4.1](ha-rest-command.md#41-gps--obd) |
| GPS만 → Traccar 위치 자동화 | [ha-rest-command.md §4.2](ha-rest-command.md#42-gps만-obd-없음) |

## 설치 (요약)

공식 문서: [traccar.org/install](https://www.traccar.org/install/)

Docker 예시:

```bash
docker run -d --name traccar \
  -p 8082:8082 \
  -p 5055:5055 \
  -v /path/to/traccar/data:/opt/traccar/data \
  traccar/traccar:latest
```

- **8082**: 웹 UI
- **5055**: OsmAnd 등 HTTP 프로토콜 수신 (HA REST Command가 사용)

## 비밀값

Traccar 서버 주소·디바이스 ID는 환경에 따라 `secrets.yaml`에 두고 **커밋하지 않습니다**.
