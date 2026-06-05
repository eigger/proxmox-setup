# packages/recorder.yaml

**Language:** [한국어](recorder.md) · [English](recorder.en.md)

[Recorder](https://www.home-assistant.io/integrations/recorder/) integration — **7-day** history retention with automatic purge, **external DB** connection.

HA path: `/config/packages/recorder.yaml`

## Prerequisites

1. Create `homeassistant` database and account on the DB server
2. `secrets.yaml`:

```yaml
recorder_db_url: "<RECORDER_DB_URL>"
```

| Example | Description |
|------|------|
| `mysql://<USER>:<PASS>@<DB_HOST>:3306/homeassistant?charset=utf8mb4` | MariaDB/MySQL |
| `postgresql://<USER>:<PASS>@<DB_HOST>:5432/homeassistant` | PostgreSQL |

For local SQLite only, remove the `db_url` entry from `recorder.yaml` (default `/config/home-assistant_v2.db`).

## Configuration

| Item | Value | Description |
|------|-----|------|
| `purge_keep_days` | `7` | Delete records older than this many days |
| `db_url` | `!secret recorder_db_url` | External DB connection string |

HA runs purge periodically. To change retention, edit `purge_keep_days` only.

## Apply

1. Add `recorder_db_url` to `secrets.yaml`
2. Deploy `packages/recorder.yaml`
3. **Developer tools → YAML** — check configuration, then restart HA

When switching to an external DB for the first time, follow the [official migration](https://www.home-assistant.io/integrations/recorder/#custom-database-engine) procedure.
