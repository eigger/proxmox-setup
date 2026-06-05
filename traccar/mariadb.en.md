# Traccar — MariaDB/MySQL operations

**Language:** [한국어](mariadb.md) · [English](mariadb.en.md)

The community-scripts **Traccar LXC** uses embedded **H2** by default. For production and long-term retention, switch to MariaDB/MySQL.

LXC install: [README.en.md](README.en.md) · Official: [MySQL/MariaDB](https://www.traccar.org/mysql/) · [Clear history](https://www.traccar.org/clear-history/)

Edit the **variables at the top** of each script, then paste the entire block into the Traccar LXC **console (root)**.

| § | Topic |
|---|-------|
| [§1](#1-mariadb-only-switch-recommended) | **MariaDB switch only** — no H2 data migration (start here) |
| [§2](#2-h2--mariadb-data-migration) | Migrate users, devices, and GPS history from H2 (optional) |
| [§3](#3-reset-mariadb) | After §2 failure: wipe DB, H2, and temp files; fresh empty MariaDB |
| [§4](#4-gps-db-cleanup-cron) | Scheduled deletion of positions and events |
| [§5](#5-server-log-cleanup-cron) | Cleanup of `/opt/traccar/logs/` application logs |

**Which section?** If you do not need old GPS or device history, run **[§1](#1-mariadb-only-switch-recommended) only**. Use [§2](#2-h2--mariadb-data-migration) only to migrate H2 data. If §2 fails, [§3](#3-reset-mariadb) resets data while keeping `traccar.xml` on MariaDB — re-register devices in the web UI.

## Environment (placeholders)

On the community-scripts **Traccar LXC**, edit **`/opt/traccar/conf/traccar.xml` only** (`conf/` contains just that file).

```bash
ls /opt/traccar/conf/
# traccar.xml
```

| Path | Contents |
|------|----------|
| `/opt/traccar/conf/traccar.xml` | Server and DB settings (edited in this guide) |
| `/opt/traccar/data/` | H2 database (`database.mv.db`) |
| `/opt/traccar/lib/` | `h2-*.jar`, etc. |
| `/opt/traccar/jre/bin/java` | Bundled JRE for §2 H2 dump when `java` is not on PATH |
| `/opt/traccar/logs/` | Application logs |

| Item | Example | Description |
|------|---------|-------------|
| Traccar config | `/opt/traccar/conf/traccar.xml` | DB connection settings |
| Traccar service | `traccar` | `systemctl restart traccar` |
| Database name | `traccar` | Traccar creates tables only; create DB and user manually |
| DB user | `<DB_USER>` | e.g. `traccar` |
| DB password | `<DB_PASSWORD>` | Do **not** commit to git |

---

## 1. MariaDB-only switch (recommended)

**Changes the DB connection only** — no H2 data migration. Traccar creates an empty schema in MariaDB; register devices again in the web UI.

| Item | Description |
|------|-------------|
| Includes | MariaDB install, DB/user creation, `traccar.xml` H2→MySQL |
| Excludes | H2 dump, import, restoring old data |
| Migrate H2 history | [§2](#2-h2--mariadb-data-migration) |
| After §2 failure | [§3](#3-reset-mariadb) — no need to re-run §1 if already on MariaDB |

```bash
# === edit only here ===
DB_USER="traccar"
DB_PASS="your_strong_password_here"
DB_HOST="localhost"          # remote DB: IP or hostname
# ======================

set -euo pipefail

CONF="/opt/traccar/conf/traccar.xml"
[[ -f "$CONF" ]] || { echo "Config missing: $CONF (check ls /opt/traccar/conf/)"; exit 1; }

echo ">> Install MariaDB"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq mariadb-server python3
systemctl enable --now mariadb

echo ">> Create database and user"
mysql <<SQL
CREATE DATABASE IF NOT EXISTS traccar CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON traccar.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

echo ">> traccar.xml H2 → MySQL"
systemctl stop traccar
export DB_USER DB_PASS DB_HOST CONF
python3 <<'PY'
from pathlib import Path
import re
import os
from xml.sax.saxutils import escape

user = os.environ["DB_USER"]
pwd = os.environ["DB_PASS"]
host = os.environ["DB_HOST"]
conf = os.environ["CONF"]
jdbc = (
    f"jdbc:mysql://{host}:3306/traccar?"
    "zeroDateTimeBehavior=round&serverTimezone=UTC&allowPublicKeyRetrieval=true"
    "&useSSL=false&allowMultiQueries=true&autoReconnect=true"
    "&useUnicode=yes&characterEncoding=UTF-8&sessionVariables=sql_mode=''"
)

def set_entry(text, key, new_val, expect_old=None):
    k = re.escape(key)
    line = f"<entry key='{key}'>{escape(str(new_val))}</entry>"
    if expect_old is not None:
        pat = rf"<entry\s+key=['\"]{k}['\"]\s*>{re.escape(expect_old)}</entry>"
        new_text, n = re.subn(pat, line, text, count=1)
        if n:
            return new_text
    for pat in (
        rf"<entry\s+key=['\"]{k}['\"]\s*/>",
        rf"<entry\s+key=['\"]{k}['\"]\s*>[^<]*</entry>",
        rf"<entry\s+key=['\"]{k}['\"]\s*>(.*?)</entry>",
    ):
        new_text, n = re.subn(pat, line, text, count=1, flags=re.DOTALL)
        if n:
            return new_text
    if re.search(rf"<entry\s+key=['\"]{k}['\"]", text):
        raise SystemExit(f"traccar.xml: cannot parse {key} — grep database {conf}")
    idx = text.rfind("</properties>")
    if idx < 0:
        raise SystemExit("missing </properties>")
    return text[:idx] + f"\n    {line}\n" + text[idx:]

p = Path(conf)
text = p.read_text(encoding="utf-8")
is_h2 = "org.h2.Driver" in text
is_mysql = "jdbc:mysql" in text or "com.mysql" in text

if is_h2:
    text = set_entry(text, "database.driver", "com.mysql.cj.jdbc.Driver", "org.h2.Driver")
    pat_url = r"<entry\s+key=['\"]database\.url['\"]\s*>jdbc:h2:[^<]*</entry>"
    if not re.search(pat_url, text):
        raise SystemExit("database.url (jdbc:h2) missing")
    text = re.sub(
        pat_url,
        f"<entry key='database.url'>{escape(jdbc)}</entry>",
        text,
        count=1,
    )
    text = set_entry(text, "database.user", user, "sa")
    text = set_entry(text, "database.password", pwd)
    p.write_text(text, encoding="utf-8")
    print(f"traccar.xml H2 → MySQL done: {p}")
elif is_mysql:
    pat_mysql = r"<entry\s+key=['\"]database\.url['\"]\s*>jdbc:mysql:[^<]*</entry>"
    if re.search(pat_mysql, text):
        text = re.sub(
            pat_mysql,
            f"<entry key='database.url'>{escape(jdbc)}</entry>",
            text,
            count=1,
        )
    text = set_entry(text, "database.user", user)
    text = set_entry(text, "database.password", pwd)
    p.write_text(text, encoding="utf-8")
    print(f"traccar.xml already MySQL — synced credentials, continuing: {p}")
else:
    raise SystemExit("cannot detect H2/MySQL — grep database " + conf)
PY

echo ">> Start Traccar"
systemctl start traccar
sleep 3
systemctl is-active traccar && echo "OK — check http://$(hostname -I | awk '{print $1}'):8082"

echo ">> (optional) H2 backup"
if [ -d /opt/traccar/data ] && ls /opt/traccar/data/*.db 2>/dev/null; then
  tar czf "/root/traccar-h2-backup-$(date +%F).tar.gz" -C /opt/traccar data
  echo "Backup: /root/traccar-h2-backup-$(date +%F).tar.gz"
fi
```

On failure: `journalctl -u traccar -n 50`

---

## 2. H2 → MariaDB data migration

Traccar provides **no official auto-migration** from H2. The script below follows the community-proven [forum guide](https://www.traccar.org/forums/topic/migration-from-h2-to-mysql/) (**H2 SQL dump → MariaDB import**). Large `tc_positions` tables may take **hours** to import.

| Item | Description |
|------|-------------|
| What moves | Users, devices, GPS tracks, events (`tc_*` tables) |
| Prerequisite | `/opt/traccar/data/database.mv.db` exists |
| During work | Traccar **stopped** — trackers may buffer data |
| Small datasets | [§1](#1-mariadb-only-switch-recommended) + re-register in the web UI may be faster |
| Re-run mid-migration | if `traccar.xml` is already MySQL, script **skips** conversion and continues with schema · H2 dump · import |

```bash
# === edit only here ===
DB_USER="traccar"
DB_PASS="your_strong_password_here"
DB_HOST="localhost"
# ======================

set -euo pipefail

CONF="/opt/traccar/conf/traccar.xml"
[[ -f "$CONF" ]] || { echo "Config missing: $CONF (check ls /opt/traccar/conf/)"; exit 1; }

H2_DB="/opt/traccar/data/database"
H2_JAR="$(ls /opt/traccar/lib/h2-*.jar 2>/dev/null | head -1)"
EXPORT="/tmp/traccar-h2-export.sql"
IMPORT="/tmp/traccar-h2-import.sql"

[[ -f "${H2_DB}.mv.db" ]] || { echo "H2 DB missing: ${H2_DB}.mv.db"; exit 1; }
[[ -n "$H2_JAR" ]] || { echo "H2 jar missing: /opt/traccar/lib/h2-*.jar"; exit 1; }

if [[ -x /opt/traccar/jre/bin/java ]]; then
  JAVA=/opt/traccar/jre/bin/java
elif command -v java >/dev/null 2>&1; then
  JAVA=java
else
  echo ">> Install OpenJDK (for H2 dump only)"
  apt-get install -y -qq default-jre-headless
  JAVA=java
fi

echo ">> Backup H2"
systemctl stop traccar
tar czf "/root/traccar-h2-backup-$(date +%F).tar.gz" -C /opt/traccar conf data
echo "Backup: /root/traccar-h2-backup-$(date +%F).tar.gz"

echo ">> Install MariaDB and create database"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq mariadb-server python3
systemctl enable --now mariadb
mysql <<SQL
CREATE DATABASE IF NOT EXISTS traccar CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON traccar.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

echo ">> traccar.xml H2 → MySQL"
export DB_USER DB_PASS DB_HOST CONF
python3 <<'PY'
from pathlib import Path
import re
import os
from xml.sax.saxutils import escape

user = os.environ["DB_USER"]
pwd = os.environ["DB_PASS"]
host = os.environ["DB_HOST"]
conf = os.environ["CONF"]
jdbc = (
    f"jdbc:mysql://{host}:3306/traccar?"
    "zeroDateTimeBehavior=round&serverTimezone=UTC&allowPublicKeyRetrieval=true"
    "&useSSL=false&allowMultiQueries=true&autoReconnect=true"
    "&useUnicode=yes&characterEncoding=UTF-8&sessionVariables=sql_mode=''"
)

def set_entry(text, key, new_val, expect_old=None):
    k = re.escape(key)
    line = f"<entry key='{key}'>{escape(str(new_val))}</entry>"
    if expect_old is not None:
        pat = rf"<entry\s+key=['\"]{k}['\"]\s*>{re.escape(expect_old)}</entry>"
        new_text, n = re.subn(pat, line, text, count=1)
        if n:
            return new_text
    for pat in (
        rf"<entry\s+key=['\"]{k}['\"]\s*/>",
        rf"<entry\s+key=['\"]{k}['\"]\s*>[^<]*</entry>",
        rf"<entry\s+key=['\"]{k}['\"]\s*>(.*?)</entry>",
    ):
        new_text, n = re.subn(pat, line, text, count=1, flags=re.DOTALL)
        if n:
            return new_text
    if re.search(rf"<entry\s+key=['\"]{k}['\"]", text):
        raise SystemExit(f"traccar.xml: cannot parse {key} — grep database {conf}")
    idx = text.rfind("</properties>")
    if idx < 0:
        raise SystemExit("missing </properties>")
    return text[:idx] + f"\n    {line}\n" + text[idx:]

p = Path(conf)
text = p.read_text(encoding="utf-8")
is_h2 = "org.h2.Driver" in text
is_mysql = "jdbc:mysql" in text or "com.mysql" in text

if is_h2:
    text = set_entry(text, "database.driver", "com.mysql.cj.jdbc.Driver", "org.h2.Driver")
    pat_url = r"<entry\s+key=['\"]database\.url['\"]\s*>jdbc:h2:[^<]*</entry>"
    if not re.search(pat_url, text):
        raise SystemExit("database.url (jdbc:h2) missing")
    text = re.sub(
        pat_url,
        f"<entry key='database.url'>{escape(jdbc)}</entry>",
        text,
        count=1,
    )
    text = set_entry(text, "database.user", user, "sa")
    text = set_entry(text, "database.password", pwd)
    p.write_text(text, encoding="utf-8")
    print(f"traccar.xml H2 → MySQL done: {p}")
elif is_mysql:
    pat_mysql = r"<entry\s+key=['\"]database\.url['\"]\s*>jdbc:mysql:[^<]*</entry>"
    if re.search(pat_mysql, text):
        text = re.sub(
            pat_mysql,
            f"<entry key='database.url'>{escape(jdbc)}</entry>",
            text,
            count=1,
        )
    text = set_entry(text, "database.user", user)
    text = set_entry(text, "database.password", pwd)
    p.write_text(text, encoding="utf-8")
    print(f"traccar.xml already MySQL — synced credentials, continuing: {p}")
else:
    raise SystemExit("cannot detect H2/MySQL — grep database " + conf)
PY

echo ">> Create MariaDB schema (start Traccar → stop)"
systemctl start traccar
sleep 5
systemctl stop traccar

echo ">> H2 SQL dump ($JAVA)"
"$JAVA" -cp "$H2_JAR" org.h2.tools.Script \
  -url "jdbc:h2:${H2_DB}" -user sa -script "$EXPORT"
echo "Dump: $EXPORT ($(du -h "$EXPORT" | awk '{print $1}'))"

echo ">> Convert to MySQL format"
python3 - "$EXPORT" "$IMPORT" <<'PY'
import re, sys

export_path, import_path = sys.argv[1], sys.argv[2]
text = open(export_path, encoding="utf-8", errors="replace").read()

inserts, buf = [], []
for line in text.splitlines():
    s = line.strip()
    if not s or s.startswith("--") or s.startswith("//"):
        continue
    if re.match(r"(?i)^INSERT\s+INTO", s):
        if buf:
            inserts.append(" ".join(buf))
        buf = [s]
    elif buf:
        buf.append(s)
        if ";" in s:
            inserts.append(" ".join(buf))
            buf = []
if buf:
    inserts.append(" ".join(buf))

def fix_tc_users_token(stmt: str) -> str:
    if not re.match(r"(?i)REPLACE\s+INTO\s+tc_users\s*\(\s*id", stmt):
        return stmt
    parts = re.split(r"\(|\)", stmt, maxsplit=4)
    if len(parts) < 5:
        return stmt
    cols = [c.strip() for c in parts[1].split(",")]
    if "token" not in cols:
        return stmt
    ti = cols.index("token")
    cols.pop(ti)
    vals = [v.strip() for v in parts[3].split(",")]
    vals.pop(ti)
    return f"{parts[0]}({', '.join(cols)}){parts[2]}({', '.join(vals)}){parts[4]}"

out = ["SET FOREIGN_KEY_CHECKS=0;"]
users_fixed = 0
for raw in inserts:
    if re.search(r"(?i)DATABASECHANGELOG", raw):
        continue
    s = raw.strip().rstrip(";")
    s = re.sub(r"(?i)public\.", "", s)
    s = s.replace('"', "")
    s = re.sub(r"(?i)^INSERT\s+INTO", "REPLACE INTO", s, count=1)
    m = re.match(r"(?i)(REPLACE\s+INTO\s+)([^\s(;]+)", s)
    if m:
        s = m.group(1) + m.group(2).lower() + s[m.end(2) :]
    s = re.sub(
        r"(?i)(REPLACE\s+INTO\s+tc_events\s*\(\s*id\s*,\s*type\s*,\s*)servertime",
        r"\1eventtime",
        s,
    )
    before = s
    s = fix_tc_users_token(s)
    if s != before:
        users_fixed += 1
    if not re.search(r"(?i)VALUES\s*\(", s):
        raise SystemExit(f"INSERT body missing (header only): {s[:120]}...")
    out.append(s + ";")

out.append("SET FOREIGN_KEY_CHECKS=1;")
open(import_path, "w", encoding="utf-8").write("\n".join(out) + "\n")
print(f"Converted {len(out) - 2} INSERT → REPLACE, tc_users token cleaned: {users_fixed}")
PY

echo ">> MariaDB import (may take a long time)"
mysql -u "$DB_USER" -p"$DB_PASS" -f traccar < "$IMPORT"

echo ">> Start Traccar"
systemctl start traccar
sleep 3
systemctl is-active traccar && echo "OK — http://$(hostname -I | awk '{print $1}'):8082"
```

After completion, verify login, map, and devices in the web UI. If devices are missing on the map, link them under **Settings → Users → Connections → Devices**. Review mysql output for import errors.

**Verify data** (migration success):

```bash
mysql -u traccar -p traccar -e "
SELECT 'users' t, COUNT(*) c FROM tc_users
UNION SELECT 'devices', COUNT(*) FROM tc_devices
UNION SELECT 'positions', COUNT(*) FROM tc_positions;"
```

If `devices` or `positions` is 0, import failed. Run `systemctl stop traccar`, then re-run from the **Convert to MySQL format** block (`EXPORT` at `/tmp/traccar-h2-export.sql` — skip H2 dump if it still exists). To give up, use [§3](#3-reset-mariadb).

---

## 3. Reset MariaDB

Use when §2 migration failed or you decide to **run MariaDB only** without old data. Keeps `traccar.xml` on MariaDB — only wipes DB contents.

| Mode | H2 files | Use case |
|------|----------|----------|
| **A. MariaDB only** | Keep | Retry §2 later |
| **B. Full wipe** | Delete | Fresh start — re-register devices in web UI |

```bash
# === edit only here ===
DB_USER="traccar"
DB_PASS="your_db_password_here"
WIPE_H2="yes"                # yes = delete H2 (mode B) | no = keep H2 (mode A)
# ======================

set -euo pipefail

systemctl stop traccar

echo ">> Reset MariaDB traccar database"
mysql -u root <<SQL
DROP DATABASE IF EXISTS traccar;
CREATE DATABASE traccar CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON traccar.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

echo ">> Remove §2 temp files"
rm -f /tmp/traccar-h2-export.sql /tmp/traccar-h2-import.sql

if [[ "${WIPE_H2}" == "yes" ]]; then
  echo ">> Delete H2 DB files"
  rm -f /opt/traccar/data/database.mv.db /opt/traccar/data/database.trace.db
else
  echo ">> H2 kept: /opt/traccar/data/database.mv.db (§2 retry possible)"
fi

systemctl start traccar
sleep 5
systemctl is-active traccar && echo "OK — http://$(hostname -I | awk '{print $1}'):8082"

mysql -u "$DB_USER" -p"$DB_PASS" traccar -e "
SELECT 'users' t, COUNT(*) c FROM tc_users
UNION SELECT 'devices', COUNT(*) FROM tc_devices
UNION SELECT 'positions', COUNT(*) FROM tc_positions;"
```

Liquibase recreates the schema on an empty DB — same as a **fresh install**. Log in (usually `admin` / `admin`), change the password, and re-add devices. If still on H2 (§1 not run), use [§1](#1-mariadb-only-switch-recommended) instead.

---

## 4. GPS DB cleanup cron

Periodically deletes `tc_positions` (GPS tracks) and `tc_events` (alarms) in the DB. Uses the [official batch-delete](https://www.traccar.org/clear-history/) approach so Traccar can keep receiving data.

Run after **§1, §2, or §3** with Traccar running. Same if you still use H2.

```bash
# === edit only here ===
DB_PASS="your_db_password"
KEEP="1 YEAR"                # 90 DAY | 6 MONTH | 1 YEAR
# ========================
DB_USER="traccar"

set -euo pipefail

echo ">> mysql client config (/root/.my.cnf)"
cat > /root/.my.cnf <<EOF
[client]
user=${DB_USER}
password=${DB_PASS}
database=traccar
EOF
chmod 600 /root/.my.cnf

echo ">> Create indexes (if missing)"
mysql <<'SQL'
CREATE INDEX IF NOT EXISTS idx_positions_fixtime ON tc_positions (fixtime);
CREATE INDEX IF NOT EXISTS idx_events_eventtime ON tc_events (eventtime);
SQL

echo ">> Daily position · event batch delete cron"
cat > /etc/cron.daily/traccar-clear-database <<'SCRIPT'
#!/bin/bash
KEEP="KEEP_PLACEHOLDER"
result=""
while [[ "$result" != *" 0 rows affected"* ]]; do
  result=$(mysql -vve "DELETE FROM tc_positions WHERE fixTime < DATE(DATE_ADD(NOW(), INTERVAL -${KEEP})) LIMIT 10000")
  sleep 1
done
result=""
while [[ "$result" != *" 0 rows affected"* ]]; do
  result=$(mysql -vve "DELETE FROM tc_events WHERE eventTime < DATE(DATE_ADD(NOW(), INTERVAL -${KEEP})) LIMIT 10000")
  sleep 1
done
SCRIPT
sed -i "s/KEEP_PLACEHOLDER/${KEEP}/" /etc/cron.daily/traccar-clear-database
chmod +x /etc/cron.daily/traccar-clear-database

echo "OK — /etc/cron.daily/traccar-clear-database (retention: ${KEEP})"
```

| Setting | Description |
|---------|-------------|
| `KEEP` | `90 DAY`, `6 MONTH`, `1 YEAR` — cutoff **rounded to a date** |
| Schedule | move file to `/etc/cron.weekly/` for weekly runs |

Test: `bash /etc/cron.daily/traccar-clear-database`

---

## 5. Server log cleanup cron

Cleans **application logs** under `/opt/traccar/logs/` (startup, connections, errors). GPS tracks live in the DB; use [§4](#4-gps-db-cleanup-cron) `KEEP` for retention.

Can run regardless of MariaDB or H2.

```bash
# === edit only here ===
LOG_DAYS="3"                 # retention in days
# =========================

set -euo pipefail

cat > /etc/cron.daily/traccar-clear-logs <<SCRIPT
#!/bin/sh
find /opt/traccar/logs/ -mtime +${LOG_DAYS} -type f -delete
SCRIPT
chmod +x /etc/cron.daily/traccar-clear-logs

echo "OK — /etc/cron.daily/traccar-clear-logs (keep last ${LOG_DAYS} days)"
```

Test: `bash /etc/cron.daily/traccar-clear-logs`

---

## 6. Troubleshooting

| Symptom | Action |
|---------|--------|
| `Config missing: /opt/traccar/conf/traccar.xml` | Not LXC layout — run `ls /opt/traccar/conf/` |
| `database.password` missing | `grep database /opt/traccar/conf/traccar.xml` — latest script inserts or replaces any format |
| `already MySQL` (old script) | latest §2 **skips** XML change and continues schema · H2 dump · import |
| `Not found in traccar.xml` | Already on MySQL or manually edited — see [§7](#7-manual-config) |
| §2 failed / messy data | [§3](#3-reset-mariadb) — keep `traccar.xml`, reset DB only |
| DB connection error | check `DB_PASS`, `DB_HOST`, `mysql -e "SHOW DATABASES;"` |
| `java: command not found` | use `/opt/traccar/jre/bin/java` — latest §2 script sets `JAVA` automatically |
| `SyntaxError` on `SET FOREIGN_KEY_CHECKS` | old script ran SQL as Python — use latest §2 Python conversion block |
| `ERROR 1064` · `public.tc_` · bare `VALUES` | old `grep ^INSERT` captured **headers only** — latest §2 parses full multi-line INSERTs |
| service `active` but no data | `mysql -f` ignores errors — run **verify counts** below and re-import |
| §2 H2 dump fails | ensure Traccar is **stopped**; check `/opt/traccar/lib/h2-*.jar` and `$JAVA -version` |
| §2 `tc_positions` import errors | invalid `fixtime` rows in H2 — see [forum](https://www.traccar.org/forums/topic/migration-from-h2-to-mysql/) |
| §2 `tc_keystore` errors | empty table is OK — Traccar regenerates tokens |
| §2 devices missing on map | **Settings → Users → Connections → Devices** |
| §1 empty UI | expected (no migration) — re-register devices or use [§2](#2-h2--mariadb-data-migration) |
| §4 slow cron | confirm indexes exist |

For GUI table copy, use SQuirreL or RazorSQL — [forum details](https://www.traccar.org/forums/topic/migration-from-h2-to-mysql/)

## 7. Manual config

Replace the four H2 lines in `/opt/traccar/conf/traccar.xml`:

```xml
<entry key='database.driver'>com.mysql.cj.jdbc.Driver</entry>
<entry key='database.url'>jdbc:mysql://localhost:3306/traccar?zeroDateTimeBehavior=round&amp;serverTimezone=UTC&amp;allowPublicKeyRetrieval=true&amp;useSSL=false&amp;allowMultiQueries=true&amp;autoReconnect=true&amp;useUnicode=yes&amp;characterEncoding=UTF-8&amp;sessionVariables=sql_mode=''</entry>
<entry key='database.user'>traccar</entry>
<entry key='database.password'>password</entry>
```

The bundled MySQL driver is sufficient; a native MariaDB driver is optional per [official docs](https://www.traccar.org/mysql/).

## 8. Security

- Do **not** commit `DB_PASS`, `/root/.my.cnf`, or `traccar.xml` credentials to the repo
- If the password contains `&`, `'`, `"`, or other special characters, use a simpler password before running the script
