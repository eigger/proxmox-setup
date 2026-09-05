# Proxmox — Google Drive 자동 백업

**Language:** [한국어](gdrive-backup.md) · [English](gdrive-backup.en.md)

[rclone](https://rclone.org/)으로 Proxmox 호스트 자원에 무리를 주지 않도록 **업로드 속도·동시 전송 개수를 제한**한 LXC/VM 덤프 백업입니다.

호스트 개요: [README.md](README.md)

로컬 덤프(`vzdump`, `/var/lib/vz/dump`)는 Proxmox 자체 백업 작업(데이터센터 → 백업)에서 별도로 매일 실행되며, 이미 완료된 결과물을 이 스크립트가 Google Drive로 동기화만 합니다.

## 1. Rclone 설치 및 Google Drive 연동

### Rclone 설치 및 설정 메뉴

```bash
curl -s https://rclone.org/install.sh | bash
rclone config
```

### 설정 단계 (순서대로)

1. **`n`** (New remote) → 이름 **`gdrive`**
2. Storage → **`drive`** (Google Drive에 해당하는 번호 또는 `drive` 입력)
3. `client_id` / `client_secret` → **Enter** (비움)
4. `scope` → **`1`** (Full access)
5. `service_account_file` → **Enter** (비움)
6. `Edit advanced config?` → **`n`**
7. `Use auto config?` → **`n`** (서버에는 GUI 브라우저가 없으므로 **반드시 `n`**)

### PC에서 Google 로그인 인증

1. Proxmox 쉘에 출력된 `rclone authorize "drive" "..."` 명령을 **전체 복사**
2. 로컬 PC(Windows cmd / Mac 터미널)에 [Rclone 설치](https://rclone.org/downloads/) 후 해당 명령 실행
3. 브라우저에서 Google 계정 로그인 → **허용(Allow)**
4. PC 터미널에 나온 토큰 JSON (`{"access_token":"..."}` 형태)을 **통째로 복사**
5. Proxmox `rclone config`의 `config_token>` 프롬프트에 붙여넣고 Enter
6. `Keep this gdrive remote?` → **`y`** → **`q`**로 설정 종료

연동 확인:

```bash
rclone lsd gdrive:
```

## 2. 백업 스크립트 생성

아래를 Proxmox 터미널에 붙여넣어 `/root/gdrive_backup.sh`를 만듭니다.

```bash
cat << 'EOF' > /root/gdrive_backup.sh
#!/bin/bash
SOURCE_DIR="/var/lib/vz/dump"
DEST_DIR="gdrive:Backup/Proxmox"
LOG_FILE="/var/log/rclone_backup.log"

echo "========================================" >> $LOG_FILE
echo "[$(date +'%Y-%m-%d %H:%M:%S')] 구글 드라이브 안전 동기화 시작" >> $LOG_FILE

# 안전장치: 속도 10MB/s, 동시 전송 2개
rclone sync "$SOURCE_DIR" "$DEST_DIR" --bwlimit 10M --transfers 2 -v >> $LOG_FILE 2>&1

if [ $? -eq 0 ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [성공] 안전 동기화 완료" >> $LOG_FILE
else
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [실패] 작업 중 오류 발생" >> $LOG_FILE
fi
echo "========================================" >> $LOG_FILE
EOF
chmod +x /root/gdrive_backup.sh
```

| 옵션 | 값 | 의미 |
|------|-----|------|
| `--bwlimit 10M` | 10 MB/s | 업로드 대역폭 상한 |
| `--transfers 2` | 2 | 동시 업로드 파일 수 |
| `rclone sync` | — | 대상을 소스와 동일하게 맞춤 (드라이브에서 로컬에 없는 덤프는 삭제될 수 있음) |

이 스크립트는 `vzdump`를 실행하지 않습니다 — 기존 Proxmox 백업 작업이 이미 `SOURCE_DIR`에 덤프를 만들어 두었다고 가정하고 그 결과만 업로드합니다. Google Drive 경로는 `DEST_DIR`에서 변경합니다.

## 3. Crontab — 매일 자동 실행

기존 Proxmox 백업 작업이 **03:00**에 완료되므로, 여유를 두고 **03:30**에 업로드를 실행합니다:

```bash
(crontab -l 2>/dev/null; echo "30 3 * * * /root/gdrive_backup.sh") | crontab -
```

기존에 `30 4 * * *`(04:30) 항목이 이미 등록되어 있다면 먼저 제거한 뒤 위 명령으로 다시 등록하세요:

```bash
crontab -l | grep -v "/root/gdrive_backup.sh" | crontab -
(crontab -l 2>/dev/null; echo "30 3 * * * /root/gdrive_backup.sh") | crontab -
```

Proxmox 백업 작업이 03:00보다 늦게 끝나는 경우 시간을 더 뒤로 조정하세요. 시간 변경: `30 3` → `분 시` (cron 형식). 확인: `crontab -l`

## 4. 유지보수

**즉시 백업:**

```bash
/root/gdrive_backup.sh
```

**실시간 로그 (종료: Ctrl+C):**

```bash
tail -f /var/log/rclone_backup.log
```

**전체 로그:**

```bash
cat /var/log/rclone_backup.log
```

**드라이브 쪽 목록 확인:**

```bash
rclone ls gdrive:Backup/Proxmox
```

## 5. 비활성화 및 삭제

### 스케줄만 제거

```bash
crontab -l | grep -v "/root/gdrive_backup.sh" | crontab -
```

### 완전 제거

```bash
crontab -l | grep -v "/root/gdrive_backup.sh" | crontab -
rm -f /root/gdrive_backup.sh /var/log/rclone_backup.log
rclone config delete gdrive
```

`rclone config delete gdrive`는 Proxmox에 저장된 OAuth 설정만 지웁니다. Google Drive에 이미 올라간 파일은 그대로입니다.

## 참고

- 이 스크립트는 로컬 덤프를 만들지 않으므로, Proxmox 백업 작업의 실행 시각·소요 시간이 바뀌면 crontab 시간도 함께 조정해야 합니다.
- `rclone sync`는 로컬 `dump`에 없는 원격 파일을 삭제할 수 있으므로, 드라이브에 수동으로 넣은 파일이 같은 경로에 있으면 주의합니다.
- `gdrive` remote 이름·`Backup/Proxmox` 경로는 환경에 맞게 통일해 두세요.
