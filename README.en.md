# proxmox-setup

**Language:** [한국어](README.md) · [English](README.en.md)

Per-VM/LXC **install and operations** configuration for Proxmox, organized by server (role) in directories.

| Server / topic | Path | Description |
|----------------|------|-------------|
| Proxmox host | [proxmox/](proxmox/) | Host backup and integrations (Google Drive, etc.) |
| Home Assistant OS | [homeassistant/](homeassistant/) | HA OS VM, [packages](homeassistant/config-structure.en.md) layout |
| FreePBX | [freepbx/](freepbx/) | IP-PBX (Asterisk + FreePBX web UI) |
| Garage | [garage/](garage/) | Vehicle maintenance and fuel tracker (Torque Pro OBD, HA integration) |
| Stash | [stash/](stash/) | Home inventory and barcode manager (barcode/Matter scan, label print, HA integration) |
| Cloudflared | [cloudflared/](cloudflared/) | Cloudflare Tunnel (LXC, [tunnel setup](cloudflared/tunnel-setup.en.md)) |
| Cloudflare DDNS | [cloudflare-ddns/](cloudflare-ddns/) | Dynamic DNS updates (LXC) |
| Tailscale | [tailscale/](tailscale/) | Subnet router LXC (mesh VPN access to the home LAN) |
| LubeLogger (unused) | [lubelogger/](lubelogger/) | Vehicle maintenance and fuel tracker (Korean translation, HA integration) |
| Traccar (unused) | [traccar/](traccar/) | GPS tracking server (HA REST Command) |
| grocy (unused) | [grocy/](grocy/) | Household and grocery inventory (Niimbot label integration) |

Each directory’s `README.md` is the entry point for **LXC/VM install and operations**. Home Assistant integration is split as follows.

| Layer | Location | Content |
|-------|----------|---------|
| LXC README | `garage/README.md`, etc. | Install, ports, **links only** to HA integration |
| Integration detail | `*/ha-*.md` | API, automations, webhooks, scenarios |
| HA packages | [homeassistant/packages/](homeassistant/packages/) | YAML for `/config/packages/` |

Full layout: [homeassistant/config-structure.en.md](homeassistant/config-structure.en.md)
