# Traccar — MariaDB/MySQL · DB cleanup

**Language:** [한국어](mariadb.md) · [English](mariadb.en.md)

The community-scripts **Traccar LXC** uses embedded **H2** by default. Paste the scripts below **as a whole** into the Traccar LXC **console (root)**.

Install: [README.en.md](README.en.md) · Official: [MySQL/MariaDB](https://www.traccar.org/mysql/) · [Clear history](https://www.traccar.org/clear-history/)

---

## 1. Switch to MariaDB — fresh start (no H2 data)

Use this when you **do not** need existing GPS, device, or user history. To migrate H2 data, use [§1M](#1m-h2--mariadb-data-migration-one-click-paste) instead.

Edit the **top 3 lines** for your environment, then copy the entire block → paste into the LXC console → Enter.

```bash
# === edit only here ===
DB_USER="traccar"
DB_PASS="your_strong_password_here"
DB_HOST="localhost"          # remote DB: IP or hostname
# ======================

set -euo pipefail

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
python3 <<PY
from pathlib import Path

user, pwd, host = "${DB_USER}", "${DB_PASS}", "${DB_HOST}"
jdbc = (
    f"jdbc:mysql://{host}:3306/traccar?"
    "zeroDateTimeBehavior=round&serverTimezone=UTC&allowPublicKeyRetrieval=true"
    "&useSSL=false&allowMultiQueries=true&autoReconnect=true"
    "&useUnicode=yes&characterEncoding=UTF-8&sessionVariables=sql_mode=''"
)
p = Path("/opt/traccar/conf/traccar.xml")
text = p.read_text(encoding="utf-8")
repl = [
    ("<entry key='database.driver'>org.h2.Driver</entry>",
     "<entry key='database.driver'>com.mysql.cj.jdbc.Driver</entry>"),
    ("<entry key='database.url'>jdbc:h2:./data/database</entry>",
     f"<entry key='database.url'>{jdbc}</entry>"),
    ("<entry key='database.user'>sa</entry>",
     f"<entry key='database.user'>{user}</entry>"),
    ("<entry key='database.password'></entry>",
     f"<entry key='database.password'>{pwd}</entry>"),
]
for old, new in repl:
    if old not in text:
        raise SystemExit(f"Not found in traccar.xml: {old[:50]}… (already migrated or different format)")
    text = text.replace(old, new)
p.write_text(text, encoding="utf-8")
print("traccar.xml updated")
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

| Item | Description |
|------|-------------|
| `DB_USER` / `DB_PASS` | MariaDB credentials — **do not commit real values** |
| `DB_HOST` | `localhost` on same LXC, or remote DB host |
| H2 data | **Not migrated by this script** — see [§1M](#1m-h2--mariadb-data-migration-one-click-paste) |

On failure: `journalctl -u traccar -n 50`

---

## 1M. H2 → MariaDB data migration (one-click paste)

**Yes, it is possible.** Traccar provides **no official auto-migration**; this uses the community-proven **H2 SQL dump → MariaDB import** flow. Large [`tc_positions`](https://www.traccar.org/forums/topic/migration-from-h2-to-mysql/) tables may take **hours**.

| Item | Description |
|------|-------------|
| What moves | Users, devices, GPS tracks, events — H2 `tc_*` tables |
| Prerequisite | `/opt/traccar/data/database.mv.db` exists (still on H2) |
| During migration | Traccar **stopped** — trackers may buffer data on device/gateway |
| References | [Forum guide](https://www.traccar.org/forums/topic/migration-from-h2-to-mysql/) · [H2 export](https://www.traccar.org/forums/topic/exporting-settings/) |

Edit the **top 3 lines**, then paste the whole block.

```bash
# === edit only here ===
DB_USER="traccar"
DB_PASS="your_strong_password_here"
DB_HOST="localhost"
# ======================

set -euo pipefail

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
python3 <<PY
from pathlib import Path
user, pwd, host = "${DB_USER}", "${DB_PASS}", "${DB_HOST}"
jdbc = (
    f"jdbc:mysql://{host}:3306/traccar?"
    "zeroDateTimeBehavior=round&serverTimezone=UTC&allowPublicKeyRetrieval=true"
    "&useSSL=false&allowMultiQueries=true&autoReconnect=true"
    "&useUnicode=yes&characterEncoding=UTF-8&sessionVariables=sql_mode=''"
)
p = Path("/opt/traccar/conf/traccar.xml")
text = p.read_text(encoding="utf-8")
repl = [
    ("<entry key='database.driver'>org.h2.Driver</entry>",
     "<entry key='database.driver'>com.mysql.cj.jdbc.Driver</entry>"),
    ("<entry key='database.url'>jdbc:h2:./data/database</entry>",
     f"<entry key='database.url'>{jdbc}</entry>"),
    ("<entry key='database.user'>sa</entry>",
     f"<entry key='database.user'>{user}</entry>"),
    ("<entry key='database.password'></entry>",
     f"<entry key='database.password'>{pwd}</entry>"),
]
for old, new in repl:
    if old not in text:
        raise SystemExit(f"Not found in traccar.xml: {old[:50]}…")
    text = text.replace(old, new)
p.write_text(text, encoding="utf-8")
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

echo ">> MariaDB import (may take a long time; -f skips some errors)"
mysql -u "$DB_USER" -p"$DB_PASS" -f traccar < "$IMPORT"

echo ">> Start Traccar"
systemctl start traccar
sleep 3
systemctl is-active traccar && echo "OK — http://$(hostname -I | awk '{print $1}'):8082"

echo ""
echo ">> Post-migration checks"
echo "  1. Log in and verify devices on the map"
echo "  2. If missing on map: Settings → Users → Connections → Devices"
echo "  3. Review mysql output above for import errors (bad event dates may be skippable)"
echo "  4. Keep H2 backup tar; delete /opt/traccar/data/*.db when satisfied"
```

| Symptom | Action |
|---------|--------|
| Devices missing on map | **Settings → Users → Connections → Devices** — link devices to your user |
| `tc_positions` import errors | Invalid `fixtime` rows in H2 (e.g. 1970-01-01) — fix per [forum](https://www.traccar.org/forums/topic/migration-from-h2-to-mysql/) |
| `tc_keystore` errors | Empty table is OK — Traccar regenerates tokens ([forum](https://www.traccar.org/forums/topic/migration-from-h2-to-mysql/)) |
| Dump fails | Ensure Traccar is **stopped**; use `/opt/traccar/lib/h2-*.jar` |
| Prefer GUI | SQuirreL / RazorSQL table copy — [forum details](https://www.traccar.org/forums/topic/migration-from-h2-to-mysql/) |

For a small number of devices/users, **§1 + re-register in the web UI** may be faster than §1M.

---

## 2. GPS position · event batch delete cron (one-click paste)

Deletes **GPS tracks and alarms** in the DB (`tc_positions`, `tc_events`) — the movement history shown on the Traccar web map.

Run **after MariaDB migration (§1)** once Traccar has started and created tables. Same if you still use H2.  
Edit the **top 2 lines** (`DB_PASS`, `KEEP`), then paste the whole block.

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

Test once immediately: `bash /etc/cron.daily/traccar-clear-database`

---

## 3. Server log retention cron (one-click paste)

**Not GPS tracking data.** Cleans **server text logs** under `/opt/traccar/logs/` (startup, connections, errors, etc.) written by the Traccar Java process. Use §2 `KEEP` for GPS track retention.

Independent of the DB — paste into the Traccar LXC **console (root)**.  
Edit the **top line** (`LOG_DAYS`) if needed.

```bash
# === edit only here ===
LOG_DAYS="3"                 # delete log files older than this many days
# =========================

set -euo pipefail

echo ">> Log cleanup cron (/opt/traccar/logs/)"
cat > /etc/cron.daily/traccar-clear-logs <<SCRIPT
#!/bin/sh
find /opt/traccar/logs/ -mtime +${LOG_DAYS} -type f -delete
SCRIPT
chmod +x /etc/cron.daily/traccar-clear-logs

echo "OK — /etc/cron.daily/traccar-clear-logs (keep last ${LOG_DAYS} days)"
```

| Setting | Description |
|---------|-------------|
| `LOG_DAYS` | `3` — keep the last N days of **server log files** (not GPS/DB) |
| Schedule | can use `/etc/cron.weekly/` etc. |

Test once immediately: `bash /etc/cron.daily/traccar-clear-logs`

---

## 4. Troubleshooting

| Symptom | Action |
|---------|--------|
| `Not found in traccar.xml` | Already on MySQL or manually edited — see [manual config](#6-manual-config-reference) |
| DB connection error | check `DB_PASS`, `DB_HOST`, `mysql -e "SHOW DATABASES;"` |
| Slow cron | confirm indexes from §2 exist |
| Empty UI after switch | §1 does not migrate H2 — use §1M or re-register devices and users |
| Empty map after migration | check **Settings → Users → Connections → Devices** |

## 6. Manual config (reference)

If you prefer not to use the paste script — replace the four H2 lines in `/opt/traccar/conf/traccar.xml`:

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
