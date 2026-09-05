# Proxmox — Google Drive automated backup

**Language:** [한국어](gdrive-backup.md) · [English](gdrive-backup.en.md)

LXC/VM dump backup via [rclone](https://rclone.org/), with **upload speed and concurrent transfer limits** to avoid overloading the Proxmox host.

Host overview: [README.en.md](README.en.md)

The local dump (`vzdump`, `/var/lib/vz/dump`) is produced separately by Proxmox's own daily backup job (Datacenter → Backup); this script only syncs the already-finished result to Google Drive.

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
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Starting safe Google Drive sync" >> $LOG_FILE

# Safety limits: 10MB/s, 2 concurrent transfers
rclone sync "$SOURCE_DIR" "$DEST_DIR" --bwlimit 10M --transfers 2 -v >> $LOG_FILE 2>&1

if [ $? -eq 0 ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] Sync completed" >> $LOG_FILE
else
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [FAILED] Error during sync" >> $LOG_FILE
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

This script does not run `vzdump` — it assumes the existing Proxmox backup job has already produced dumps in `SOURCE_DIR` and only uploads them. Change the Google Drive path in `DEST_DIR`.

## 3. Crontab — daily run

The existing Proxmox backup job finishes at **03:00**, so run the upload at **04:00** to leave a safety margin:

```bash
(crontab -l 2>/dev/null; echo "0 4 * * * /root/gdrive_backup.sh") | crontab -
```

If a `30 4 * * *` (04:30) entry is already registered, remove it first, then re-register with the command above:

```bash
crontab -l | grep -v "/root/gdrive_backup.sh" | crontab -
(crontab -l 2>/dev/null; echo "0 4 * * * /root/gdrive_backup.sh") | crontab -
```

If the Proxmox backup job finishes later, push the time back further. Change time: `0 4` → `minute hour` (cron format). Verify: `crontab -l`

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

- This script doesn't create the local dump, so if the Proxmox backup job's schedule or duration changes, adjust the crontab time accordingly.
- `rclone sync` may delete remote files not present in the local `dump`; be careful if you manually placed files on the drive at the same path.
- Keep the `gdrive` remote name and `Backup/Proxmox` path consistent for your environment.
