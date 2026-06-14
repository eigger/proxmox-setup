# Linksys PAP2 / PAP2T

**Language:** [한국어](linksys-pap2.md) · [English](linksys-pap2.en.md)

Register Linksys PAP2 or PAP2T ATA (Analog Telephone Adapter) as a FreePBX PJSIP extension.

LXC and PBX: [README.en.md](README.en.md) · HA AMI: [ha-asterisk.en.md](ha-asterisk.en.md)

## 1. Prerequisites (FreePBX extension)

Create the extension on the PBX before connecting the PAP2.

1. Open FreePBX web admin → **Applications → Extensions**
2. **Add Extension → Add New PJSIP Extension**
3. Enter the following, then save:
   - **User Extension:** extension number (e.g. `<TARGET_EXT>`)
   - **Display Name:** display name (any)
   - **Secret:** authentication password (needed for ATA config — record separately)
4. **Apply Config** (top right) to apply changes

## 2. Access ATA web configuration

1. Connect an analog phone to the PAP2 `Line 1` port
2. Pick up the handset and dial **`****`** (four asterisks) → after voice prompt, dial **`110#`** to hear the IP address
3. Open that IP address in a web browser → administration page
4. Click **Admin Login** (top right) → click **switch to advanced view** (enables advanced settings mode)

## 3. Line settings (SIP registration)

Navigate to the **Line 1** (or Line 2) tab and configure settings as below.

| Setting (Parameter) | Recommended value | Description |
|------|------|------|
| **Line Enable** | `yes` | Enable the line |
| **Proxy** | `<FREEPBX_IP>` | FreePBX LAN IP (specify as `<FREEPBX_IP>:<PORT>` if using non-standard port. e.g. `<FREEPBX_IP>:5060`) |
| **Register** | `yes` | Enable registration with server |
| **Register Expires** | `3600` | Registration expiry interval (seconds) |
| **Display Name** | `<TARGET_EXT>` | Outbound display name (any) |
| **User ID** | `<TARGET_EXT>` | FreePBX **extension number** |
| **Password** | *(Secret)* | FreePBX extension Secret (**do not commit**) |
| **Use Auth ID** | `yes` | Enable Authentication ID |
| **Auth ID** | `<TARGET_EXT>` | Same as extension number |
| **NAT Mapping Enable** | `no` / `yes` | `yes` if behind a router/NAT (usually `no` for local LAN) |
| **NAT Keep Alive Enable** | `yes` | Send keep-alive packets |
| **SIP Port** | `5060` (Line 1) / `5061` (Line 2) | Local listening port on the PAP2 device |

## 4. South Korea phone environment (optional)

Recommended for domestic analog phone compatibility and consistent ringback.

### Regional tab settings

Navigate to the **Regional** tab and modify the following parameters:

#### Call Progress Tones
- **Dial Tone:** `350@-19,440@-19;30(*/0/1+2)` (Standard South Korean dial tone)
- **Busy Tone:** `480@-19,620@-19;10(.25/.25/1+2)` (Standard busy signal)
- **Reorder Tone:** `480@-19,620@-19;10(.25/.25/1+2)`
- **Ring Back Tone:** `440@-19,480@-19;20(.5/2/1+2)` (Standard ringback - approx. 1s On / 2s Off pattern)

#### Ring Cadence
- **Ring1 Cadence:** `60(1/2)` (South Korea standard: 1 second ring followed by 2 seconds pause) or `60(2/4)` (North America standard: 2 seconds ring followed by 4 seconds pause)
  - *Tip: To increase/customize the ring and pause durations, modify the numbers inside the parentheses in seconds. The syntax is `60(RingDuration/PauseDuration)` (e.g., `60(2/5)` for a 2s ring and 5s pause, or `60(1.5/3.5)` allowing decimal values).*

#### Miscellaneous
- **Time Zone:** `GMT+09:00` (Korean Standard Time)
- **FXS Port Impedance:** `600` (Standard 600 ohm impedance in Korea)


## 5. Save and verify connection

1. Click **Save Settings** at the bottom of the page
2. After reboot, navigate to the **Info** tab at the top
3. Verify that **Registration State** under `Line 1 Status` / `Line 2 Status` is **Registered**

If registration fails: double-check the FreePBX IP, extension Secret, firewall settings (UDP 5060, RTP port range), and verify if **Apply Config** was successfully applied on FreePBX.

## 6. Factory reset (Reference)

Recommended if using a pre-owned device or if configuration provision settings are corrupted.

1. Pick up the phone handset and dial **`****`**
2. When the voice menu starts, dial **`73738#`** (R-E-S-E-T)
3. Press **`1`** to confirm and wait for the device to reboot
