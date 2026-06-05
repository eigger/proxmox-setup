# Traccar — MariaDB/MySQL · DB 정리

**Language:** [한국어](mariadb.md) · [English](mariadb.en.md)

community-scripts **Traccar LXC**는 기본 **H2** DB를 사용합니다. 아래 스크립트는 Traccar LXC **콘솔(root)** 에 **통째로 붙여넣기**하면 됩니다.

설치: [README.md](README.md) · 공식: [MySQL/MariaDB](https://www.traccar.org/mysql/) · [Clear history](https://www.traccar.org/clear-history/)

---

## 1. MariaDB 전환 — 신규 (H2 데이터 미이전)

기존 GPS·디바이스·사용자 기록 **없이** MariaDB로 새로 시작할 때. H2 데이터를 옮기려면 [§1M](#1m-h2--mariadb-데이터-마이그레이션-원클릭)을 사용하세요.

**맨 위 3줄만** 환경에 맞게 고친 뒤, 블록 전체를 복사 → LXC 콘솔에 붙여넣기 → Enter.

```bash
# === 여기만 수정 ===
DB_USER="traccar"
DB_PASS="여기에_강한_비밀번호"
DB_HOST="localhost"          # 원격 DB면 IP/호스트명
# ====================

set -euo pipefail

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
        raise SystemExit(f"traccar.xml에서 찾을 수 없음: {old[:50]}… (이미 전환됐거나 파일 형식 다름)")
    text = text.replace(old, new)
p.write_text(text, encoding="utf-8")
print("traccar.xml 업데이트 완료")
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

| 항목 | 설명 |
|------|------|
| `DB_USER` / `DB_PASS` | MariaDB 계정 — **git·문서에 실제값 커밋 금지** |
| `DB_HOST` | 같은 LXC면 `localhost`, 외부 DB면 해당 호스트 |
| H2 데이터 | **이 스크립트는 이전하지 않음** — [§1M](#1m-h2--mariadb-데이터-마이그레이션-원클릭) 참고 |

실패 시: `journalctl -u traccar -n 50`

---

## 1M. H2 → MariaDB 데이터 마이그레이션 (원클릭)

**가능합니다.** Traccar 공식 **자동 마이그레이션은 없고**, 커뮤니티에서 검증된 **H2 SQL 덤프 → MariaDB import** 방식입니다. [`tc_positions`](https://www.traccar.org/forums/topic/migration-from-h2-to-mysql/)가 크면 **수 시간** 걸릴 수 있습니다.

| 항목 | 설명 |
|------|------|
| 이전 대상 | 사용자·디바이스·GPS 궤적·이벤트 등 H2의 `tc_*` 테이블 |
| 사전 조건 | `/opt/traccar/data/database.mv.db` 존재 (H2 사용 중) |
| 마이그레이션 중 | Traccar **중지** — GPS 단말 데이터는 단말·게이트웨이에 버퍼될 수 있음 |
| 참고 | [포럼 가이드](https://www.traccar.org/forums/topic/migration-from-h2-to-mysql/) · [H2 내보내기](https://www.traccar.org/forums/topic/exporting-settings/) |

**맨 위 3줄** 수정 후 통째로 붙여넣기.

```bash
# === 여기만 수정 ===
DB_USER="traccar"
DB_PASS="여기에_강한_비밀번호"
DB_HOST="localhost"
# ====================

set -euo pipefail

H2_DB="/opt/traccar/data/database"
H2_JAR="$(ls /opt/traccar/lib/h2-*.jar 2>/dev/null | head -1)"
EXPORT="/tmp/traccar-h2-export.sql"
IMPORT="/tmp/traccar-h2-import.sql"

[[ -f "${H2_DB}.mv.db" ]] || { echo "H2 DB 없음: ${H2_DB}.mv.db"; exit 1; }
[[ -n "$H2_JAR" ]] || { echo "H2 jar 없음: /opt/traccar/lib/h2-*.jar"; exit 1; }

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
        raise SystemExit(f"traccar.xml에서 찾을 수 없음: {old[:50]}…")
    text = text.replace(old, new)
p.write_text(text, encoding="utf-8")
PY

echo ">> MariaDB 스키마 생성 (Traccar 기동 → 중지)"
systemctl start traccar
sleep 5
systemctl stop traccar

echo ">> H2 SQL 덤프"
java -cp "$H2_JAR" org.h2.tools.Script \
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

echo ">> MariaDB import (오래 걸릴 수 있음, -f 로 일부 오류는 건너뜀)"
mysql -u "$DB_USER" -p"$DB_PASS" -f traccar < "$IMPORT"

echo ">> Traccar 기동"
systemctl start traccar
sleep 3
systemctl is-active traccar && echo "OK — http://$(hostname -I | awk '{print $1}'):8082"

echo ""
echo ">> 마이그레이션 후 확인"
echo "  1. 웹 UI 로그인·지도에 디바이스 표시 확인"
echo "  2. 지도에 안 보이면: 설정 → 사용자 → 연결 → 디바이스 에서 연결"
echo "  3. import 오류는 위 mysql 출력 확인 (잘못된 날짜 이벤트 등은 무시 가능)"
echo "  4. 확인 후 H2 백업 tar 유지, 필요 없으면 /opt/traccar/data/*.db 삭제 가능"
```

| 증상 | 조치 |
|------|------|
| 지도에 디바이스 없음 | **설정 → 사용자 → 연결 → 디바이스** 에서 사용자에 디바이스 연결 |
| `tc_positions` import 오류 | H2에 잘못된 `fixtime`(1970-01-01 등) 행 — [포럼](https://www.traccar.org/forums/topic/migration-from-h2-to-mysql/) 참고해 해당 행 수정 |
| `tc_keystore` 오류 | 빈 테이블로 두면 Traccar가 토큰 재생성 ([포럼](https://www.traccar.org/forums/topic/migration-from-h2-to-mysql/)) |
| 덤프 실패 | Traccar **중지** 상태인지 확인, H2 jar 버전은 `/opt/traccar/lib/h2-*.jar` 사용 |
| GUI 선호 | SQuirreL·RazorSQL로 테이블 복사 — [포럼 상세](https://www.traccar.org/forums/topic/migration-from-h2-to-mysql/) |

디바이스·사용자만 소량이면 §1M 대신 **§1 + 웹 UI에서 재등록**이 더 빠를 수 있습니다.

---

## 2. GPS 위치·이벤트 배치 삭제 cron (원클릭)

DB에 쌓이는 **GPS 궤적·알람**(`tc_positions`, `tc_events`)을 주기적으로 지웁니다. Traccar 웹 UI 지도에 보이는 이동 기록이 여기 해당합니다.

**MariaDB 전환(§1) 후** Traccar가 한 번 기동되어 테이블이 생긴 뒤 실행합니다. H2를 그대로 쓰는 경우에도 동일합니다.  
**맨 위 2줄**(`DB_PASS`, `KEEP`)만 수정 후 통째로 붙여넣기.

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
| 실행 주기 | 파일을 `/etc/cron.weekly/`로 옮기면 주 1회 |

즉시 1회 테스트: `bash /etc/cron.daily/traccar-clear-database`

---

## 3. 서버 로그 3일 보관 cron (원클릭)

**GPS 추적 기록이 아닙니다.** Traccar Java 프로세스가 `/opt/traccar/logs/`에 남기는 **서버 텍스트 로그**(기동·연결·오류 등)만 정리합니다. GPS 궤적 보관은 §2 `KEEP`으로 조절하세요.

DB와 무관 — Traccar LXC **콘솔(root)** 에 통째로 붙여넣기.  
**맨 위 1줄**(`LOG_DAYS`)만 필요 시 수정.

```bash
# === 여기만 수정 ===
LOG_DAYS="3"                 # 보관 일수 (이보다 오래된 로그 파일 삭제)
# ====================

set -euo pipefail

echo ">> 로그 정리 cron (/opt/traccar/logs/)"
cat > /etc/cron.daily/traccar-clear-logs <<SCRIPT
#!/bin/sh
find /opt/traccar/logs/ -mtime +${LOG_DAYS} -type f -delete
SCRIPT
chmod +x /etc/cron.daily/traccar-clear-logs

echo "OK — /etc/cron.daily/traccar-clear-logs (최근 ${LOG_DAYS}일 보관)"
```

| 조정 | 설명 |
|------|------|
| `LOG_DAYS` | `3` — **서버 로그 파일** 기준 최근 N일만 유지 (GPS·DB 무관) |
| 실행 주기 | `/etc/cron.weekly/` 등으로 변경 가능 |

즉시 1회 테스트: `bash /etc/cron.daily/traccar-clear-logs`

---

## 4. 문제 해결

| 증상 | 조치 |
|------|------|
| `traccar.xml에서 찾을 수 없음` | 이미 MySQL 전환됐거나 설정 파일 수동 편집됨 — [수동 설정](#6-수동-설정-참고) |
| DB 연결 오류 | `DB_PASS`·`DB_HOST` 확인, `mysql -e "SHOW DATABASES;"` |
| cron 느림 | §2 인덱스 생성 여부 확인 |
| 전환 후 빈 UI | §1 사용 시 H2 미이전 — §1M 또는 디바이스·사용자 재등록 |
| 마이그레이션 후 지도 빈칸 | **설정 → 사용자 → 연결 → 디바이스** 확인 |

## 6. 수동 설정 (참고)

원클릭 스크립트 대신 직접 편집할 때 — `/opt/traccar/conf/traccar.xml`에서 H2 4줄을 아래로 교체:

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
