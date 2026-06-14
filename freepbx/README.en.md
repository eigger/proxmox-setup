# FreePBX

**Language:** [한국어](README.md) · [English](README.en.md)

[FreePBX](https://www.freepbx.org/) — an [Asterisk](https://www.asterisk.org/)-based IP-PBX. Reference for self-hosting on Proxmox LXC and integrating with Grandstream ATA and Home Assistant.

## Installation

Proxmox VE **LXC** install script: [FreePBX — Proxmox VE Helper Scripts](https://community-scripts.org/scripts/freepbx)

Uses the official [FreePBX Debian install script](https://github.com/FreePBX/sng_freepbx_debian_install).

1. Run the command below from the Proxmox host **Shell**
2. In the wizard, choose **Default** or **Advanced**, then create the LXC

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/freepbx.sh)"
```

Web UI after install: `http://<FREEPBX_IP>` (default port **80**)

### Initial setup

1. Configure static IP, hostname, and DNS
2. Set the initial admin account in the web UI
3. Allow SIP/RTP and HTTPS (443) through the firewall
4. **Connectivity → Trunks / Extensions** — create extensions, then **Apply Config**

## Device integration

| Topic | Document |
|------|------|
| Grandstream HT801/HT802 (SIP extension) | [grandstream-ht801-ht802.en.md](grandstream-ht801-ht802.en.md) |
| Linksys PAP2/PAP2T (SIP extension) | [linksys-pap2.en.md](linksys-pap2.en.md) |

## Home Assistant integration

AMI and ha-sip are **add-on, UI, and automation** based; there is no combined package in `homeassistant/packages/`.

| Integration guide | Document |
|-------------|------|
| AMI (`asterisk.send_action`) | [ha-asterisk.en.md](ha-asterisk.en.md) |
| ha-sip (SIP + Edge TTS) | [ha-sip.en.md](ha-sip.en.md) |
| HA packages and secrets layout | [homeassistant/config-structure.en.md](../homeassistant/config-structure.en.md) |

## Environment (placeholders)

| Device | IP | Notes |
|------|-----|------|
| FreePBX | `<FREEPBX_IP>` | PBX LAN address |
| Home Assistant | `<HA_IP>` | AMI and ha-sip target |
| Grandstream ATA | DHCP/static | Extension e.g. `<TARGET_EXT>` |
| ha-sip (HA) | — | SIP extension `<HA_SIP_EXT>` |

### Ports (defaults)

| Purpose | Port | Protocol |
|------|------|----------|
| SIP | 5060 | UDP/TCP |
| SIP TLS | 5061 | TCP |
| AMI | 5038 | TCP |
| RTP | 10000–20000 | UDP |
| HTTPS | 443 | TCP |

In NAT environments, Proxmox and router port forwarding must match FreePBX `External Address`.

### Architecture summary

```
[HA]  AMI :5038 ──────────────┐
[HA]  ha-sip :5060 ───────────┼──► [FreePBX] ──SIP──► [Grandstream]
```

1. Create a PJSIP Extension
2. Register Grandstream or Linksys PAP2 → [grandstream-ht801-ht802.en.md](grandstream-ht801-ht802.en.md) / [linksys-pap2.en.md](linksys-pap2.en.md)
3. (Optional) AMI → [ha-asterisk.en.md](ha-asterisk.en.md)
4. (Optional) ha-sip → [ha-sip.en.md](ha-sip.en.md)

## Folder layout

```
freepbx/
├── README.md
├── README.en.md
├── grandstream-ht801-ht802.md
├── grandstream-ht801-ht802.en.md
├── linksys-pap2.md          # Linksys PAP2/PAP2T integration
├── linksys-pap2.en.md
├── ha-asterisk.md           # HA AMI integration
├── ha-asterisk.en.md
├── ha-sip.md                # HA ha-sip add-on
└── ha-sip.en.md
```

## Secrets

Do **not commit** SIP trunk credentials, Extension Secret, AMI Secret, or API keys.

### Backup

- FreePBX **Backup & Restore** module or `fwconsole backup`
- Proxmox host: [proxmox/gdrive-backup.en.md](../proxmox/gdrive-backup.en.md)
