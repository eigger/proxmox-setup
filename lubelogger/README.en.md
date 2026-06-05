# LubeLogger

**Language:** [한국어](README.md) · [English](README.en.md)

[LubeLogger](https://lubelogger.com) — a web app for vehicle maintenance and fuel economy logging. This folder holds reference setup and translation material for self-hosting on Proxmox VM/LXC or Docker.

## Installation

Proxmox VE **LXC** install script: [LubeLogger — Proxmox VE Helper Scripts](https://community-scripts.org/scripts/lubelogger)

1. Run the command below on the Proxmox host **Shell**
2. Choose **Default** or **Advanced** in the wizard to create the LXC

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/lubelogger.sh)"
```

Web UI after install: `http://<LUBELOGGER_IP>:5000` (default port **5000**)

## Home Assistant integration

| packages (`/config/packages/`) | Description |
|----------------------------------|------|
| [lubelogger.yaml](../homeassistant/packages/lubelogger.yaml) | REST Command (odometer, fuel) |
| [opinet.yaml](../homeassistant/packages/opinet.yaml) | Opinet gas station price REST sensors |

| Integration guide | Document |
|-------------|------|
| REST Command · OBD odometer automation | [ha-rest-command.en.md](ha-rest-command.en.md) |
| Fuel (Opinet API · script · dashboard) | [ha-fuel-opinet.en.md](ha-fuel-opinet.en.md) |
| HA packages · secrets layout | [homeassistant/config-structure.en.md](../homeassistant/config-structure.en.md) |

## Folder structure

```
lubelogger/
├── README.md
├── ha-rest-command.md       # HA integration details (automation · OBD)
├── ha-fuel-opinet.md        # Fuel integration details (Opinet · script)
└── translations/
    └── Asia/
        └── ko_KR.json         # Korean translation
```

HA packages: [lubelogger.yaml](../homeassistant/packages/lubelogger.yaml), [opinet.yaml](../homeassistant/packages/opinet.yaml)

The `translations/` layout matches the official translation repo [hargata/lubelog_translations](https://github.com/hargata/lubelog_translations). For PR submission, copy `Asia/ko_KR.json` as-is.

## Korean translation

Korean strings live in `translations/Asia/ko_KR.json`. When editing, change **values** only — do not modify **keys**.

- Edit and submit via the LubeLogger UI **Translation Editor**
- Docs: [Translations – LubeLogger Wiki](https://docs.lubelogger.com/Misc/Translations)

### Reference

| Item | Description |
|------|------|
| Filename | ISO 639-1 + region: `ko_KR.json` |
| Region folder | Korea → `Asia/` |
| English source | [lubelog/wwwroot/defaults/en_US.json](https://github.com/hargata/lubelog/blob/main/wwwroot/defaults/en_US.json) |
| Official translation PRs | [lubelog_translations](https://github.com/hargata/lubelog_translations) (3 approvals required to merge) |
| Untranslated UI | About, SweetAlert dialogs, top-right Toast, etc. |

### Apply to your instance

1. Upload `ko_KR.json` via LubeLogger **Settings → Manage Languages → Upload**
2. Or use **Get Translations** from the official repo, then replace with your custom file

## Secrets

Do **not** commit SMTP, OIDC, API keys, or similar credentials.
