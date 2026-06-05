# Grandstream HT801/HT802

**Language:** [한국어](grandstream-ht801-ht802.md) · [English](grandstream-ht801-ht802.en.md)

Register [Grandstream](https://www.grandstream.com/) HT801/HT802 ATA as a FreePBX PJSIP extension.

LXC and PBX: [README.en.md](README.en.md) · HA AMI: [ha-asterisk.en.md](ha-asterisk.en.md)

## 1. Prerequisites (FreePBX extension)

Create the extension on the PBX before connecting the HT801/802.

1. Open FreePBX web admin → **Applications → Extensions**
2. **Add Extension → Add New PJSIP Extension**
3. Enter the following, then save:
   - **User Extension:** extension number (e.g. `<TARGET_EXT>`)
   - **Display Name:** display name (any)
   - **Secret:** authentication password (needed for ATA config — record separately)
4. **Apply Config** (top right) to apply changes

HA integration uses **FreePBX AMI**, not a separate SIP registration. → [ha-asterisk.en.md](ha-asterisk.en.md)

## 2. Access ATA web configuration

1. Connect an analog phone to the HT801/802 `Phone` port
2. Pick up the handset and dial **`***`** → after voice prompt, dial **`02`** to hear the IP
3. Open that IP in a browser → admin page (default credentials on device label or manual)

## 3. Profile / FXS Port settings

Under **PROFILES** (older firmware: **FXS PORTS**), map settings as below.

If there are many fields, use browser search to find Parameter names.

| Setting (Parameter) | Recommended value | Description |
|------|------|------|
| **Account Active** | `Yes` | Enable the port |
| **Primary SIP Server** | `<FREEPBX_IP>` | FreePBX LAN IP |
| **SIP Transport** | `UDP` | Default protocol |
| **SIP Registration** | `Yes` | Enable server registration |
| **SIP User ID** | `<TARGET_EXT>` | FreePBX **extension number** |
| **Authenticate ID** | `<TARGET_EXT>` | Same as extension number |
| **Authenticate Password** | *(Secret)* | FreePBX extension Secret (**do not commit**) |
| **Name** | `<TARGET_EXT>` | Outbound display name (any) |
| **Local SIP Port** | `5060` | FreePBX PJSIP port |

## 4. South Korea phone environment (optional)

Recommended for domestic analog phone compatibility and consistent ringback.

- **SLIC Setting:** `CHINA CO` or `STANDARD 900 ohms` (impedance, reduces distorted ring)
- **Caller ID Scheme:** `Bellcore/Telcordia` (domestic CID display)
- **Preferred Vocoder:**
  - Choice 1: **PCMA** (G.711a)
  - Choice 2: **PCMU** (G.711u)

## 5. Save and verify connection

1. **Save** or **Apply** at the bottom of the page
2. After reboot, open **STATUS**
3. If `Port Status` → `Registration` is **Registered** (green), integration is complete

If registration fails: check PBX IP, Secret, firewall (UDP 5060, RTP range), and **Apply Config**.

## 6. Firmware update

Latest firmware and release notes: [Grandstream Firmware and Release Notes](https://www.grandstream.com/support/firmware)

On the page, find **HT801 V2** / **HT802 V2** under **Gateways and ATA's → HandyTone ATA's**. Read **Release Notes** first; download the ZIP for manual upload if needed. (Example stable version at doc writing time: `1.0.11.4` — follow the version shown on the site.)

Grandstream recommends firmware upgrades over **HTTP**; the public upgrade server also uses HTTP. Do not add an `http://` prefix to `Firmware Server Path`.

### Before upgrade

1. Check current firmware version in **STATUS**
2. Back up SIP settings: **Advanced Settings** (or **Maintenance**) → **Download Device Configuration** / export XML, or record settings separately
3. Phone and registration will be interrupted during upgrade

### Method A: Auto upgrade from HTTP server (recommended)

ATA web UI → **Advanced Settings** (some firmware: **Maintenance → Upgrade and Provisioning**) → **Firmware Upgrade and Provisioning**:

| Item | Setting |
|------|------|
| **Always Check for New Firmware** | `Yes` |
| **Upgrade via** | `HTTP` |
| **Firmware Server Path** | `firmware.grandstream.com` |

1. **Save** → **Apply** at the bottom
2. **Reboot** and wait until complete (power LED and web UI back)
3. In **STATUS**, confirm firmware version increased; verify **Profile / FXS Port** settings if needed

Leave **Always Check for New Firmware** enabled to check for new firmware on boot.

### Method B: Upload file from PC

1. From the [firmware page](https://www.grandstream.com/support/firmware), download the ZIP for HT801 V2 / HT802 V2
2. Extract — model binaries e.g. `ht801fw.bin`, `ht802fw.bin` (check ZIP filenames and manual)
3. Web UI **Advanced Settings** → **Upload Firmware** → select file → **Apply** / **Reboot**

### HT801/802 V2 notes

- After upgrading to **1.0.9.3 or later**, **downgrade to 1.0.7.5 or below is not supported** (official Release Notes).
- Firmware marked with `*` may include limited fixes/features only — always read Release Notes.
- If downgrade or factory reset is needed, keep the backup file from **before** upgrade.

### After upgrade

1. Confirm **STATUS → Port Status → Registration** is **Registered** again
2. If extension, codec, or Korea settings (section 4) were reset, reapply **Profile / FXS Port**
3. If issues persist, restore from backup XML via **Upload Configuration** (version compatibility in Release Notes)
