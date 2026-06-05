# Traccar — MariaDB/MySQL 운영

**Language:** [한국어](mariadb.md) · [English](mariadb.en.md)

community-scripts **Traccar LXC**는 기본 **H2** DB를 사용합니다. 운영·장기 보관에는 MariaDB/MySQL 전환을 권장합니다.

LXC 설치: [README.md](README.md) · 공식: [MySQL/MariaDB](https://www.traccar.org/mysql/) · [Clear history](https://www.traccar.org/clear-history/)

각 절의 스크립트는 Traccar LXC **콘솔(root)** 에서 **맨 위 변수만 수정**한 뒤 블록 전체를 붙여넣어 실행합니다.

| § | 내용 |
|---|------|
| [§1](#1-mariadb-신규-전환) | H2 데이터 없이 MariaDB로 새로 시작 |
| [§2](#2-h2--mariadb-데이터-마이그레이션) | H2 사용자·디바이스·GPS 기록 이전 |
| [§3](#3-gps-db-정리-cron) | DB 위치·이벤트 주기 삭제 |
| [§4](#4-서버-로그-정리-cron) | `/opt/traccar/logs/` 애플리케이션 로그 정리 |

## 환경 (플레이스홀더)

community-scripts **Traccar LXC** 기준 경로입니다. 설정은 **`/opt/traccar/conf/traccar.xml` 한 파일**만 수정합니다 (`conf/`에 다른 XML을 두지 않음).

```bash
ls /opt/traccar/conf/
# traccar.xml
```

| 경로 | 내용 |
|------|------|
| `/opt/traccar/conf/traccar.xml` | DB·서버 설정 (이 문서에서 편집) |
| `/opt/traccar/data/` | H2 DB (`database.mv.db`) |
| `/opt/traccar/lib/` | `h2-*.jar` 등 |
| `/opt/traccar/jre/bin/java` | Traccar 번들 JRE (§2 H2 덤프 — `java`가 PATH에 없을 때) |
| `/opt/traccar/logs/` | 애플리케이션 로그 |

| 항목 | 예시 | 설명 |
|------|------|------|
| Traccar 설정 | `/opt/traccar/conf/traccar.xml` | DB 연결 설정 |
| Traccar 서비스 | `traccar` | `systemctl restart traccar` |
| DB 이름 | `traccar` | Traccar가 테이블만 생성, DB·계정은 수동 생성 |
| DB 사용자 | `<DB_USER>` | 예: `traccar` |
| DB 비밀번호 | `<DB_PASSWORD>` | **git에 커밋하지 않음** |

---

## 1. MariaDB 신규 전환

기존 GPS·디바이스·사용자 기록을 **이전하지 않고** MariaDB로 새로 시작할 때 사용합니다. H2 데이터를 옮기려면 [§2](#2-h2--mariadb-데이터-마이그레이션)를 사용하세요.

```bash
# === 여기만 수정 ===
DB_USER="traccar"
DB_PASS="여기에_강한_비밀번호"
DB_HOST="localhost"          # 원격 DB면 IP/호스트명
# ====================

set -euo pipefail

CONF="/opt/traccar/conf/traccar.xml"
[[ -f "$CONF" ]] || { echo "설정 없음: $CONF (ls /opt/traccar/conf/ 확인)"; exit 1; }

echo ">> MariaDB 설치"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq mariadb-server python3
systemctl enable --now mariadb

echo ">> DB·계정 생성"
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
        raise SystemExit(f"traccar.xml: {key} 형식 인식 실패 — grep database {conf}")
    idx = text.rfind("</properties>")
    if idx < 0:
        raise SystemExit("</properties> 없음")
    return text[:idx] + f"\n    {line}\n" + text[idx:]

p = Path(conf)
text = p.read_text(encoding="utf-8")
is_h2 = "org.h2.Driver" in text
is_mysql = "jdbc:mysql" in text or "com.mysql" in text

if is_h2:
    text = set_entry(text, "database.driver", "com.mysql.cj.jdbc.Driver", "org.h2.Driver")
    pat_url = r"<entry\s+key=['\"]database\.url['\"]\s*>jdbc:h2:[^<]*</entry>"
    if not re.search(pat_url, text):
        raise SystemExit("database.url (jdbc:h2) 없음")
    text = re.sub(
        pat_url,
        f"<entry key='database.url'>{escape(jdbc)}</entry>",
        text,
        count=1,
    )
    text = set_entry(text, "database.user", user, "sa")
    text = set_entry(text, "database.password", pwd)
    p.write_text(text, encoding="utf-8")
    print(f"traccar.xml H2 → MySQL 완료: {p}")
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
    print(f"traccar.xml 이미 MySQL — user/password 동기화 후 계속: {p}")
else:
    raise SystemExit("H2/MySQL 설정 인식 실패 — grep database " + conf)
PY

echo ">> Traccar 기동"
systemctl start traccar
sleep 3
systemctl is-active traccar && echo "OK — http://$(hostname -I | awk '{print $1}'):8082 확인"

echo ">> (선택) H2 파일 백업"
if [ -d /opt/traccar/data ] && ls /opt/traccar/data/*.db 2>/dev/null; then
  tar czf "/root/traccar-h2-backup-$(date +%F).tar.gz" -C /opt/traccar data
  echo "백업: /root/traccar-h2-backup-$(date +%F).tar.gz"
fi
```

실패 시: `journalctl -u traccar -n 50`

---

## 2. H2 → MariaDB 데이터 마이그레이션

Traccar는 H2→MariaDB **공식 자동 마이그레이션을 제공하지 않습니다.** 아래 스크립트는 [포럼](https://www.traccar.org/forums/topic/migration-from-h2-to-mysql/)에서 검증된 **H2 SQL 덤프 → MariaDB import** 절차입니다. `tc_positions`가 크면 import에 **수 시간** 걸릴 수 있습니다.

| 항목 | 설명 |
|------|------|
| 이전 대상 | 사용자·디바이스·GPS 궤적·이벤트 (`tc_*` 테이블) |
| 사전 조건 | `/opt/traccar/data/database.mv.db` 존재 |
| 작업 중 | Traccar **중지** — 단말·게이트웨이에 데이터가 버퍼될 수 있음 |
| 소량 데이터 | 디바이스·사용자가 적으면 [§1](#1-mariadb-신규-전환) + 웹 UI 재등록이 더 빠를 수 있음 |
| 중간 재실행 | `traccar.xml`이 이미 MySQL이면 **변환 건너뛰고** 스키마·H2 덤프·import부터 이어감 |

```bash
# === 여기만 수정 ===
DB_USER="traccar"
DB_PASS="여기에_강한_비밀번호"
DB_HOST="localhost"
# ====================

set -euo pipefail

CONF="/opt/traccar/conf/traccar.xml"
[[ -f "$CONF" ]] || { echo "설정 없음: $CONF (ls /opt/traccar/conf/ 확인)"; exit 1; }

H2_DB="/opt/traccar/data/database"
H2_JAR="$(ls /opt/traccar/lib/h2-*.jar 2>/dev/null | head -1)"
EXPORT="/tmp/traccar-h2-export.sql"
IMPORT="/tmp/traccar-h2-import.sql"

[[ -f "${H2_DB}.mv.db" ]] || { echo "H2 DB 없음: ${H2_DB}.mv.db"; exit 1; }
[[ -n "$H2_JAR" ]] || { echo "H2 jar 없음: /opt/traccar/lib/h2-*.jar"; exit 1; }

if [[ -x /opt/traccar/jre/bin/java ]]; then
  JAVA=/opt/traccar/jre/bin/java
elif command -v java >/dev/null 2>&1; then
  JAVA=java
else
  echo ">> OpenJDK 설치 (H2 덤프용, Traccar 서비스와 별도)"
  apt-get install -y -qq default-jre-headless
  JAVA=java
fi

echo ">> H2 백업"
systemctl stop traccar
tar czf "/root/traccar-h2-backup-$(date +%F).tar.gz" -C /opt/traccar conf data
echo "백업: /root/traccar-h2-backup-$(date +%F).tar.gz"

echo ">> MariaDB 설치·DB 생성"
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
        raise SystemExit(f"traccar.xml: {key} 형식 인식 실패 — grep database {conf}")
    idx = text.rfind("</properties>")
    if idx < 0:
        raise SystemExit("</properties> 없음")
    return text[:idx] + f"\n    {line}\n" + text[idx:]

p = Path(conf)
text = p.read_text(encoding="utf-8")
is_h2 = "org.h2.Driver" in text
is_mysql = "jdbc:mysql" in text or "com.mysql" in text

if is_h2:
    text = set_entry(text, "database.driver", "com.mysql.cj.jdbc.Driver", "org.h2.Driver")
    pat_url = r"<entry\s+key=['\"]database\.url['\"]\s*>jdbc:h2:[^<]*</entry>"
    if not re.search(pat_url, text):
        raise SystemExit("database.url (jdbc:h2) 없음")
    text = re.sub(
        pat_url,
        f"<entry key='database.url'>{escape(jdbc)}</entry>",
        text,
        count=1,
    )
    text = set_entry(text, "database.user", user, "sa")
    text = set_entry(text, "database.password", pwd)
    p.write_text(text, encoding="utf-8")
    print(f"traccar.xml H2 → MySQL 완료: {p}")
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
    print(f"traccar.xml 이미 MySQL — user/password 동기화 후 계속: {p}")
else:
    raise SystemExit("H2/MySQL 설정 인식 실패 — grep database " + conf)
PY

echo ">> MariaDB 스키마 생성 (Traccar 기동 → 중지)"
systemctl start traccar
sleep 5
systemctl stop traccar

echo ">> H2 SQL 덤프 ($JAVA)"
"$JAVA" -cp "$H2_JAR" org.h2.tools.Script \
  -url "jdbc:h2:${H2_DB}" -user sa -script "$EXPORT"
echo "덤프: $EXPORT ($(du -h "$EXPORT" | awk '{print $1}'))"

echo ">> MySQL 형식 변환"
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
print(f"tc_users token 컬럼 {n}건 정리")
PY

echo ">> MariaDB import (오래 걸릴 수 있음)"
mysql -u "$DB_USER" -p"$DB_PASS" -f traccar < "$IMPORT"

echo ">> Traccar 기동"
systemctl start traccar
sleep 3
systemctl is-active traccar && echo "OK — http://$(hostname -I | awk '{print $1}'):8082"
```

완료 후 웹 UI에서 로그인·지도·디바이스 표시를 확인합니다. 지도에 디바이스가 없으면 **설정 → 사용자 → 연결 → 디바이스**에서 사용자에 연결합니다. import 오류는 스크립트 출력의 mysql 메시지를 확인하세요.

---

## 3. GPS DB 정리 cron

DB `tc_positions`(GPS 궤적)·`tc_events`(알람)를 주기적으로 삭제합니다. [공식 배치 삭제](https://www.traccar.org/clear-history/) 방식으로 소량씩 DELETE하여 Traccar 수신을 막지 않습니다.

**§1 또는 §2** 완료 후 Traccar가 기동된 상태에서 실행합니다. H2를 그대로 쓰는 경우에도 동일합니다.

```bash
# === 여기만 수정 ===
DB_PASS="여기에_DB_비밀번호"
KEEP="1 YEAR"                # 90 DAY | 6 MONTH | 1 YEAR
# ====================
DB_USER="traccar"

set -euo pipefail

echo ">> mysql 클라이언트 설정 (/root/.my.cnf)"
cat > /root/.my.cnf <<EOF
[client]
user=${DB_USER}
password=${DB_PASS}
database=traccar
EOF
chmod 600 /root/.my.cnf

echo ">> 인덱스 생성 (없으면 추가)"
mysql <<'SQL'
CREATE INDEX IF NOT EXISTS idx_positions_fixtime ON tc_positions (fixtime);
CREATE INDEX IF NOT EXISTS idx_events_eventtime ON tc_events (eventtime);
SQL

echo ">> 매일 위치·이벤트 배치 삭제 cron"
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

echo "OK — /etc/cron.daily/traccar-clear-database (보관: ${KEEP})"
```

| 조정 | 설명 |
|------|------|
| `KEEP` | `90 DAY`, `6 MONTH`, `1 YEAR` — **날짜 단위**로 잘림 |
| 실행 주기 | `/etc/cron.weekly/`로 옮기면 주 1회 |

테스트: `bash /etc/cron.daily/traccar-clear-database`

---

## 4. 서버 로그 정리 cron

Traccar가 `/opt/traccar/logs/`에 기록하는 **애플리케이션 로그**(기동·연결·오류)를 정리합니다. GPS 궤적은 DB에 저장되며 보관 기간은 [§3](#3-gps-db-정리-cron) `KEEP`으로 조절합니다.

MariaDB/H2와 무관하게 실행할 수 있습니다.

```bash
# === 여기만 수정 ===
LOG_DAYS="3"                 # 보관 일수
# ====================

set -euo pipefail

cat > /etc/cron.daily/traccar-clear-logs <<SCRIPT
#!/bin/sh
find /opt/traccar/logs/ -mtime +${LOG_DAYS} -type f -delete
SCRIPT
chmod +x /etc/cron.daily/traccar-clear-logs

echo "OK — /etc/cron.daily/traccar-clear-logs (최근 ${LOG_DAYS}일 보관)"
```

테스트: `bash /etc/cron.daily/traccar-clear-logs`

---

## 5. 문제 해결

| 증상 | 조치 |
|------|------|
| `설정 없음: /opt/traccar/conf/traccar.xml` | LXC가 아니거나 경로 다름 — `ls /opt/traccar/conf/` |
| `database.password` / 항목 없음 | `grep database /opt/traccar/conf/traccar.xml` — 항목 누락·자기닫힘 태그는 최신 스크립트가 처리 |
| `이미 MySQL` 메시지 (구 스크립트) | 최신 §2는 **건너뛰고** 스키마·H2 덤프·import 계속 |
| `traccar.xml에서 찾을 수 없음` | 이미 MySQL 전환됐거나 수동 편집됨 — [§6](#6-수동-설정) |
| DB 연결 오류 | `DB_PASS`·`DB_HOST` 확인, `mysql -e "SHOW DATABASES;"` |
| `java: command not found` | `/opt/traccar/jre/bin/java` 사용 — 최신 §2 스크립트 또는 `JAVA=/opt/traccar/jre/bin/java` |
| §2 H2 덤프 실패 | Traccar **중지** 확인, `/opt/traccar/lib/h2-*.jar`, `$JAVA -version` |
| §2 `tc_positions` import 오류 | H2에 잘못된 `fixtime` 행 — [포럼](https://www.traccar.org/forums/topic/migration-from-h2-to-mysql/) 참고 |
| §2 `tc_keystore` 오류 | 빈 테이블이면 Traccar가 토큰 재생성 |
| §2 후 지도에 디바이스 없음 | **설정 → 사용자 → 연결 → 디바이스** |
| §1 후 빈 UI | H2 미이전 — [§2](#2-h2--mariadb-데이터-마이그레이션) 또는 재등록 |
| §3 cron 느림 | 인덱스 생성 여부 확인 |

GUI로 테이블 복사를 선호하면 SQuirreL·RazorSQL — [포럼 상세](https://www.traccar.org/forums/topic/migration-from-h2-to-mysql/)

## 6. 수동 설정

`/opt/traccar/conf/traccar.xml`에서 H2 4줄을 아래로 교체:

```xml
<entry key='database.driver'>com.mysql.cj.jdbc.Driver</entry>
<entry key='database.url'>jdbc:mysql://localhost:3306/traccar?zeroDateTimeBehavior=round&amp;serverTimezone=UTC&amp;allowPublicKeyRetrieval=true&amp;useSSL=false&amp;allowMultiQueries=true&amp;autoReconnect=true&amp;useUnicode=yes&amp;characterEncoding=UTF-8&amp;sessionVariables=sql_mode=''</entry>
<entry key='database.user'>traccar</entry>
<entry key='database.password'>비밀번호</entry>
```

[MariaDB 네이티브 드라이버](https://www.traccar.org/mysql/)는 Traccar 번들 MySQL 드라이버로 충분합니다.

## 7. 보안

- `DB_PASS`·`/root/.my.cnf`·`traccar.xml` — **저장소에 커밋하지 않음**
- DB 비밀번호에 `&`, `'`, `"` 등 XML/쉘 특수문자가 있으면 스크립트 전 **영문·숫자 위주로 변경** 권장
