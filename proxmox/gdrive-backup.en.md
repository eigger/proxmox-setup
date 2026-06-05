# Proxmox — Google Drive automated backup

**Language:** [한국어](gdrive-backup.md) · [English](gdrive-backup.en.md)

LXC/VM dump backup via [rclone](https://rclone.org/), with **upload speed and concurrent transfer limits** to avoid overloading the Proxmox host.

Host overview: [README.en.md](README.en.md)

1. **Step 1:** Local LXC/VM dumps with `vzdump` (`/var/lib/vz/dump`)
2. **Step 2:** Sync to Google Drive with `rclone sync`

## 1. Install Rclone and link Google Drive

### Install Rclone and open config

```bash
curl -s https://rclone.org/install.sh | bash
rclone config
```

### Config steps (in order)

1. **`n`** (New remote) → name **`gdrive`**
2. Storage → **`drive`** (number for Google Drive or type `drive`)
3. `client_id` / `client_secret` → **Enter** (leave blank)
4. `scope` → **`1`** (Full access)
5. `service_account_file` → **Enter** (leave blank)
6. `Edit advanced config?` → **`n`**
7. `Use auto config?` → **`n`** (no GUI browser on the server — **must be `n`**)

### Authorize Google login from a PC

1. Copy the full `rclone authorize "drive" "..."` command printed in the Proxmox shell
2. On a local PC (Windows cmd / Mac terminal), [install Rclone](https://rclone.org/downloads/) and run that command
3. Sign in with Google in the browser → **Allow**
4. Copy the entire token JSON from the PC terminal (`{"access_token":"..."}` form)
5. Paste into the Proxmox `rclone config` `config_token>` prompt and press Enter
6. `Keep this gdrive remote?` → **`y`** → **`q`** to exit config

Verify the link:

```bash
rclone lsd gdrive:
```

## 2. Create the backup script

Paste the following in the Proxmox terminal to create `/root/gdrive_backup.sh`.

```bash
cat << 'EOF' > /root/gdrive_backup.sh
#!/bin/bash
SOURCE_DIR="/var/lib/vz/dump"
DEST_DIR="gdrive:Backup/Proxmox"
LOG_FILE="/var/log/rclone_backup.log"

echo "========================================" >> $LOG_FILE
echo "[$(date +'%Y-%m-%d %H:%M:%S')] 1단계: Proxmox LXC/VM 로컬 백업 시작" >> $LOG_FILE

# 모든 LXC/VM을 무중단 압축 백업
vzdump --all --mode snapshot --compress zstd >> $LOG_FILE 2>&1

echo "[$(date +'%Y-%m-%d %H:%M:%S')] 2단계: 구글 드라이브 안전 동기화 시작" >> $LOG_FILE

# 안전장치: 속도 10MB/s, 동시 전송 2개
rclone sync "$SOURCE_DIR" "$DEST_DIR" --bwlimit 10M --transfers 2 -v >> $LOG_FILE 2>&1

if [ $? -eq 0 ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [성공] 백업 및 안전 동기화 완료" >> $LOG_FILE
else
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [실패] 작업 중 오류 발생" >> $LOG_FILE
fi
echo "========================================" >> $LOG_FILE
EOF
chmod +x /root/gdrive_backup.sh
```

| Option | Value | Meaning |
|--------|-------|---------|
| `--bwlimit 10M` | 10 MB/s | Upload bandwidth cap |
| `--transfers 2` | 2 | Concurrent upload file count |
| `rclone sync` | — | Match destination to source (dumps not present locally may be deleted on the drive) |

To back up specific VMs/LXCs only, change the script to use VMIDs instead of `vzdump --all`. Change the Google Drive path in `DEST_DIR`.

## 3. Crontab — daily run

Run daily at **04:30**:

```bash
(crontab -l 2>/dev/null; echo "30 4 * * * /root/gdrive_backup.sh") | crontab -
```

Change time: `30 4` → `minute hour` (cron format). Verify: `crontab -l`

## 4. Maintenance

**Run backup immediately:**

```bash
/root/gdrive_backup.sh
```

**Live log (exit: Ctrl+C):**

```bash
tail -f /var/log/rclone_backup.log
```

**Full log:**

```bash
cat /var/log/rclone_backup.log
```

**List remote files:**

```bash
rclone ls gdrive:Backup/Proxmox
```

## 5. Disable and remove

### Remove schedule only

```bash
crontab -l | grep -v "/root/gdrive_backup.sh" | crontab -
```

### Full removal

```bash
crontab -l | grep -v "/root/gdrive_backup.sh" | crontab -
rm -f /root/gdrive_backup.sh /var/log/rclone_backup.log
rclone config delete gdrive
```

`rclone config delete gdrive` only removes OAuth settings stored on Proxmox. Files already on Google Drive remain.

## Notes

- The first `vzdump --all` can take a long time depending on VM/LXC count and disk size.
- `rclone sync` may delete remote files not present in the local `dump`; be careful if you manually placed files on the drive at the same path.
- Keep the `gdrive` remote name and `Backup/Proxmox` path consistent for your environment.
