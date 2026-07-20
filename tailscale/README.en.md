# Tailscale

**Language:** [한국어](README.md) · [English](README.en.md)

[Tailscale](https://tailscale.com/) — WireGuard-based mesh VPN. The script in this repo creates a dedicated LXC configured as a **Subnet Router**, letting other devices on your tailnet reach private IPs on your home LAN (e.g. the Proxmox host, Home Assistant, NAS) as-is.

## Installation

Proxmox VE **LXC** install script (custom script hosted in this repo, not community-scripts):

1. Run the command below on the Proxmox host **Shell**
2. Follow the wizard prompts for CTID, resources, bridge, and IP mode (press Enter to accept defaults)
3. The LAN subnet (advertise-routes) is **auto-detected** from the Proxmox host's bridge (default `vmbr0`) IP/CIDR and used as the default — accurate for a flat single-subnet (single `vmbr0`) setup. If you have multiple VLANs/subnets, override it at the prompt
4. Providing a Tailscale auth key logs in and finishes the subnet-router setup during install; leaving it blank means you complete login manually afterward with `pct exec <CTID> -- tailscale up --advertise-routes=<CIDR>`

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/eigger/proxmox-setup/master/tailscale/ct/tailscale.sh)"
```

Pre-set any value as an env var to skip that prompt; set all of them and the install runs fully unattended as one line:

```bash
CTID=110 HOSTNAME=tailscale IP_MODE=dhcp ADVERTISE_CIDR=192.168.1.0/24 \
AUTHKEY=tskey-auth-xxxxx bash -c "$(curl -fsSL https://raw.githubusercontent.com/eigger/proxmox-setup/master/tailscale/ct/tailscale.sh)"
```

Supported vars: `CTID`, `HOSTNAME`, `CORES`, `MEMORY`, `DISK_SIZE`, `BRIDGE`, `ROOTFS_STORAGE`, `TEMPLATE_STORAGE`, `IP_MODE` (`dhcp`/`static`), `STATIC_IP`, `STATIC_GW`, `ADVERTISE_CIDR`, `AUTHKEY`.

### Required after install: approve the route

Advertising a subnet route does **not** open access by itself — it must be approved in the admin console.

1. Go to the [Tailscale admin console → Machines](https://login.tailscale.com/admin/machines)
2. Find the LXC you just created (by hostname) → **Edit route settings** → **Approve** the advertised subnet
3. On other devices that need access (phone, laptop, etc.), make sure **Use subnet routes / Accept routes** is enabled in the Tailscale client

Once approved and accepted, other tailnet devices can reach LAN private IPs directly (e.g. `http://192.168.1.50:8123`) — no port forwarding or public IP exposure required.

## How it works

- The LXC is an unprivileged container; the `/dev/net/tun` device Tailscale needs is passed through by appending entries directly to the container config (`/etc/pve/lxc/<CTID>.conf`).
- `net.ipv4.ip_forward` / `net.ipv6.conf.all.forwarding` are enabled inside the container so it can relay traffic between the tailnet and the LAN.
- Your home router (ISP router) is never touched — the LXC acts purely as a **relay**, not a gateway replacement.

## Folder Structure

```
tailscale/
├── README.md
├── README.en.md
└── ct/
    └── tailscale.sh          # LXC creation + Tailscale install + subnet router setup
```

## Secrets

The Tailscale auth key is **never committed** — it's only entered interactively at the install prompt.
