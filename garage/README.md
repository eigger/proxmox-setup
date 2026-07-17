# Garage

**Language:** [한국어](README.md) · [English](README.en.md)

[Garage](https://github.com/eigger/garage) — 가족·홈랩용 셀프호스팅 차량 관리 웹 앱 (정비 스케줄, 주유 기록, 알림, OBD/GPS 주행 및 Home Assistant 연동).

## 설치

Proxmox VE **LXC** 설치 스크립트:

1. Proxmox 호스트 **Shell**에서 아래 명령 실행
2. 마법사 설정에 따라 LXC 생성

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/eigger/garage/master/proxmox/ct/garage.sh)"
```

설치 후 웹 UI: `http://<GARAGE_IP>` (기본 포트 **80**)

### 초기 설정

1. 첫 접속 시 사용자 테이블이 비어있으면 **최초 관리자 생성(Bootstrap Admin)** 페이지가 표시됩니다. 이름·이메일·비밀번호를 설정하여 관리자 계정을 생성합니다.
2. 하단 네비게이션의 **더보기(More)** → **차량 관리(Vehicle Management)**에서 차량을 등록합니다. 차량의 연료 타입에 맞는 정비 마스터 프리셋 및 세금/보험 등의 법정 스케줄이 자동으로 복사됩니다.

## Home Assistant 연동

| packages (`/config/packages/`) | 설명 |
|----------------------------------|------|
| [garage.yaml](../homeassistant/packages/garage.yaml) | Garage 텔레메트리 REST Command 및 센서 정의 |

| 연동 가이드 | 문서 |
|-------------|------|
| HA packages·secrets 구조 | [homeassistant/config-structure.md](../homeassistant/config-structure.md) |

### 1. Telemetry 수집 및 전송 (HA → Garage)
차량 주행 시 실시간 위치, 속도, 주행거리 등의 데이터를 Garage 서버로 전송합니다. `/config/packages/garage.yaml`에 정의된 `garage_send_telemetry` REST Command를 이용하여 자동화를 구성합니다.
* **인증 방법**: 차량 등록 후 **차량 설정 → OBD & GPS**에서 발급받은 `apiToken`을 사용합니다 (Authorization Bearer 헤더 또는 `?token=TOKEN` 쿼리 파라미터).
* **호출 Endpoint**: `POST http://<GARAGE_IP>/api/ingest/telemetry`

### 2. 차량 상태 및 정비 알림 조회 (Garage → HA)
Garage의 차량 센서 데이터 및 대기 중인 정비 알림을 HA의 `rest` 플랫폼 센서로 연동하여 모니터링합니다.
* **차량 상태 API**: `GET http://<GARAGE_IP>/api/ingest/status?token=<VEHICLE_API_TOKEN>`
* **정비 알림 API**: `GET http://<GARAGE_IP>/api/ingest/reminders?token=<VEHICLE_API_TOKEN>`

## 폴더 구조

```
garage/
└── README.md
```

HA packages: [garage.yaml](../homeassistant/packages/garage.yaml)

## 비밀값

Garage 호스트 주소 및 API 토큰은 `secrets.yaml`에 보관하며 **커밋하지 않습니다**.
```yaml
garage_host: "http://<GARAGE_IP>"
garage_vehicle_token: "YOUR_VEHICLE_API_TOKEN"
```
