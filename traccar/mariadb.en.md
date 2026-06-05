# Traccar — MariaDB/MySQL operations

**Language:** [한국어](mariadb.md) · [English](mariadb.en.md)

The community-scripts **Traccar LXC** uses embedded **H2** by default. For production and long-term retention, switch to MariaDB/MySQL.

LXC install: [README.en.md](README.en.md) · Official: [MySQL/MariaDB](https://www.traccar.org/mysql/) · [Clear history](https://www.traccar.org/clear-history/)

Edit the **variables at the top** of each script, then paste the entire block into the Traccar LXC **console (root)**.

| § | Topic |
|---|-------|
| [§1](#1-fresh-mariadb-setup) | Fresh MariaDB setup (no H2 data) |
| [§2](#2-h2--mariadb-data-migration) | Migrate users, devices, and GPS history from H2 |
| [§3](#3-gps-db-cleanup-cron) | Scheduled deletion of positions and events |
| [§4](#4-server-log-cleanup-cron) | Cleanup of `/opt/traccar/logs/` application logs |

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
| `/opt/traccar/logs/` | Application logs |

| Item | Example | Description |
|------|---------|-------------|
| Traccar config | `/opt/traccar/conf/traccar.xml` | DB connection settings |
| Traccar service | `traccar` | `systemctl restart traccar` |
| Database name | `traccar` | Traccar creates tables only; create DB and user manually |
| DB user | `<DB_USER>` | e.g. `traccar` |
| DB password | `<DB_PASSWORD>` | Do **not** commit to git |

---

## 1. Fresh MariaDB setup

Use when you **do not** need to keep existing GPS, device, or user history. To migrate H2 data, use [§2](#2-h2--mariadb-data-migration).

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
if "org.h2.Driver" not in text:
    if "jdbc:mysql" in text or "com.mysql" in text:
        raise SystemExit("already MySQL/MariaDB — check traccar.xml")
    raise SystemExit("H2 database.driver missing — grep database " + conf)

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
print(f"traccar.xml updated: {p}")
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
| Small datasets | [§1](#1-fresh-mariadb-setup) + re-register in the web UI may be faster |

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
if "org.h2.Driver" not in text:
    if "jdbc:mysql" in text or "com.mysql" in text:
        raise SystemExit("already MySQL/MariaDB — check traccar.xml")
    raise SystemExit("H2 database.driver missing — grep database " + conf)

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
print(f"traccar.xml updated: {p}")
PY

echo ">> Create MariaDB schema (start Traccar → stop)"
systemctl start traccar
sleep 5
systemctl stop traccar

echo ">> H2 SQL dump"
java -cp "$H2_JAR" org.h2.tools.Script \
  -url "jdbc:h2:${H2_DB}" -user sa -script "$EXPORT"
echo "Dump: $EXPORT ($(du -h "$EXPORT" | awk '{print $1}'))"

echo ">> Convert to MySQL format"
{
  echo "SET FOREIGN_KEY_CHECKS=0;"
  grep -ai "^INSERT" "$EXPORT" | grep -av DATABASECHANGELOG \
    | sed 's/PUBLIC\.//g; s/"//g' \
    | sed -e 's/INSERT INTO \(.*\) VALUES/INSERT INTO \L\1 \UVALUES/' \
    | sed 's/INSERT/REPLACE/' \
    | sed 's/REPLACE INTO tc_events(id, type, servertime/REPLACE INTO tc_events(id, type, eventtime/'
  echo "SET FOREIGN_KEY_CHECKS=1;"
} > "$IMPORT"

python3 <<'PY' "$IMPORT"
import re, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    lines = f.readlines()
out, n = [], 0
for line in lines:
    if line.startswith("REPLACE INTO tc_users(id"):
        parts = re.split(r"\(|\)", line, maxsplit=4)
        cols = [c.strip() for c in parts[1].split(",")]
        if "token" in cols:
            ti = cols.index("token")
            cols.pop(ti)
            vals = [v.strip() for v in parts[3].split(",")]
            vals.pop(ti)
            line = f"{parts[0]}({', '.join(cols)}){parts[2]}({', '.join(vals)}){parts[4]}"
            n += 1
    out.append(line)
with open(path, "w", encoding="utf-8") as f:
    f.writelines(out)
print(f"Stripped token column from {n} tc_users rows")
PY

echo ">> MariaDB import (may take a long time)"
mysql -u "$DB_USER" -p"$DB_PASS" -f traccar < "$IMPORT"

echo ">> Start Traccar"
systemctl start traccar
sleep 3
systemctl is-active traccar && echo "OK — http://$(hostname -I | awk '{print $1}'):8082"
```

After completion, verify login, map, and devices in the web UI. If devices are missing on the map, link them under **Settings → Users → Connections → Devices**. Review mysql output for import errors.

---

## 3. GPS DB cleanup cron

Periodically deletes `tc_positions` (GPS tracks) and `tc_events` (alarms) in the DB. Uses the [official batch-delete](https://www.traccar.org/clear-history/) approach so Traccar can keep receiving data.

Run after [§1](#1-fresh-mariadb-setup) or [§2](#2-h2--mariadb-data-migration). Same if you still use H2.

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

## 4. Server log cleanup cron

Cleans **application logs** under `/opt/traccar/logs/` (startup, connections, errors). GPS tracks live in the DB; use [§3](#3-gps-db-cleanup-cron) `KEEP` for retention.

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

## 5. Troubleshooting

| Symptom | Action |
|---------|--------|
| `Config missing: /opt/traccar/conf/traccar.xml` | Not LXC layout — run `ls /opt/traccar/conf/` |
| `database.password` missing | `grep database /opt/traccar/conf/traccar.xml` — latest script inserts or replaces any format |
| `already MySQL/MariaDB` | partial §1 run — see [§6](#6-manual-config) |
| `Not found in traccar.xml` | Already on MySQL or manually edited — see [§6](#6-manual-config) |
| DB connection error | check `DB_PASS`, `DB_HOST`, `mysql -e "SHOW DATABASES;"` |
| §2 H2 dump fails | ensure Traccar is **stopped**; use `/opt/traccar/lib/h2-*.jar` |
| §2 `tc_positions` import errors | invalid `fixtime` rows in H2 — see [forum](https://www.traccar.org/forums/topic/migration-from-h2-to-mysql/) |
| §2 `tc_keystore` errors | empty table is OK — Traccar regenerates tokens |
| §2 devices missing on map | **Settings → Users → Connections → Devices** |
| §1 empty UI | H2 not migrated — use [§2](#2-h2--mariadb-data-migration) or re-register |
| §3 slow cron | confirm indexes exist |

For GUI table copy, use SQuirreL or RazorSQL — [forum details](https://www.traccar.org/forums/topic/migration-from-h2-to-mysql/)

## 6. Manual config

Replace the four H2 lines in `/opt/traccar/conf/traccar.xml`:

```xml
<entry key='database.driver'>com.mysql.cj.jdbc.Driver</entry>
<entry key='database.url'>jdbc:mysql://localhost:3306/traccar?zeroDateTimeBehavior=round&amp;serverTimezone=UTC&amp;allowPublicKeyRetrieval=true&amp;useSSL=false&amp;allowMultiQueries=true&amp;autoReconnect=true&amp;useUnicode=yes&amp;characterEncoding=UTF-8&amp;sessionVariables=sql_mode=''</entry>
<entry key='database.user'>traccar</entry>
<entry key='database.password'>password</entry>
```

The bundled MySQL driver is sufficient; a native MariaDB driver is optional per [official docs](https://www.traccar.org/mysql/).

## 7. Security

- Do **not** commit `DB_PASS`, `/root/.my.cnf`, or `traccar.xml` credentials to the repo
- If the password contains `&`, `'`, `"`, or other special characters, use a simpler password before running the script
