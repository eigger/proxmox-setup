# packages/recorder.yaml

[Recorder](https://www.home-assistant.io/integrations/recorder/) 통합 — 히스토리 **7일 보관** 후 자동 purge, **외부 DB** 연결.

HA 경로: `/config/packages/recorder.yaml`

## 사전 조건

1. DB 서버에 `homeassistant` 데이터베이스·계정 생성
2. `secrets.yaml`:

```yaml
recorder_db_url: "<RECORDER_DB_URL>"
```

| 예시 | 설명 |
|------|------|
| `mysql://<USER>:<PASS>@<DB_HOST>:3306/homeassistant?charset=utf8mb4` | MariaDB/MySQL |
| `postgresql://<USER>:<PASS>@<DB_HOST>:5432/homeassistant` | PostgreSQL |

로컬 SQLite만 쓸 때는 `recorder.yaml`에서 `db_url` 항목을 삭제합니다 (기본 `/config/home-assistant_v2.db`).

## 설정

| 항목 | 값 | 설명 |
|------|-----|------|
| `purge_keep_days` | `7` | 이 일수보다 오래된 기록 삭제 |
| `db_url` | `!secret recorder_db_url` | 외부 DB 연결 문자열 |

purge는 HA가 주기적으로 실행합니다. 보관 기간 변경 시 `purge_keep_days`만 수정하면 됩니다.

## 적용

1. `secrets.yaml`에 `recorder_db_url` 추가
2. `packages/recorder.yaml` 배치
3. **개발자 도구 → YAML** 구성 확인 후 HA 재시작

외부 DB로 처음 전환할 때는 [공식 마이그레이션](https://www.home-assistant.io/integrations/recorder/#custom-database-engine) 절차를 따릅니다.
