# Drop

**Language:** [한국어](README.md) · [English](README.en.md)

[Drop](https://github.com/eigger/drop) — A lightweight, self-hosted file sharing service designed for seamless file transfers between mobile and PC (Android Web Share Target PWA, resumable 8MB chunked uploads, folder management, soft-delete trash bin, multi-select zip downloads).

## Installation

Proxmox VE **LXC** install script:

1. Run the command below on the Proxmox host **Shell**
2. Follow the wizard steps to create the LXC

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/eigger/drop/main/proxmox/ct/drop.sh)"
```

Web UI after installation: `http://<DROP_IP>` (default port **80**)

### Initial Setup

1. On first run, if the user table is empty, you will be redirected to the **Bootstrap Admin** registration page. Enter your details to create the administrator account.
2. Log in with the admin account to manage users and start transferring files.

## Folder Structure

```
drop/
├── README.md
└── README.en.md
```
