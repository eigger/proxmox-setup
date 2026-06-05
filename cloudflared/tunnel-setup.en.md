# Cloudflare Tunnel setup

**Language:** [한국어](tunnel-setup.md) · [English](tunnel-setup.en.md)

Assumes a Cloudflare account with a **domain already connected**. Covers opening a tunnel with `cloudflared` on a Proxmox LXC and exposing internal services on subdomains.

Instead of **Cloudflare DNS + NPM (Nginx Proxy Manager)**, you can connect directly via tunnel **Public Hostname** and reach services externally without NPM.

```
Internet ──► Cloudflare ──► cloudflared LXC ──► LAN services (Proxmox, HA, …)
```

| Step | Document |
|------|----------|
| LXC install | [README.en.md](README.en.md#installation) |
| **Tunnel setup** | This document |

## Prerequisites

- **Domain** registered and delegated in Cloudflare
- [cloudflared LXC](https://community-scripts.org/scripts/cloudflared) installed on Proxmox

## 1. Create a tunnel in Cloudflare

1. Open [Cloudflare Zero Trust](https://one.dash.cloudflare.com/)  
   - First-time use may require Zero Trust setup and billing details
2. **Networks → Tunnels → Create a tunnel**
3. Connector: select **Cloudflared**
4. Enter a tunnel **name** (e.g. `homelab`, `proxmox-tunnel`)
5. The install screen shows a **token** for the next step (`eyJhIjoi...` form). **Copy it; do not commit to git or docs**

## 2. Register cloudflared service on the LXC

On Proxmox, open **cloudflared LXC → Console**, remove the default service created by the script, then reinstall with the **token from the dashboard**.

```bash
systemctl disable cloudflared
rm /etc/systemd/system/cloudflared.service
systemctl daemon-reexec
systemctl daemon-reload

sudo cloudflared service install <TUNNEL_TOKEN>
```

Replace `<TUNNEL_TOKEN>` with the value copied in [1. Create a tunnel in Cloudflare](#1-create-a-tunnel-in-cloudflare).

Check service status:

```bash
systemctl status cloudflared
```

## 3. Public Hostname — subdomain mapping

In Zero Trust **Tunnels → your tunnel → Public Hostname**, register **subdomain → internal URL** as you would in NPM.

| Field | Example |
|-------|---------|
| Subdomain | `proxmox` |
| Domain | `example.com` |
| Service type | HTTP / HTTPS |
| URL | `https://<PROXMOX_IP>:8006` |

Add a Hostname per service (HA, grocy, LubeLogger, etc.).

### HTTPS backends (Proxmox, etc.)

If the target uses **self-signed HTTPS** (Proxmox web UI, etc.), enable **Additional application settings → TLS → No TLS Verify**.

Otherwise cloudflared may fail backend certificate verification.

## 4. DNS check

In Cloudflare **DNS → Records**, confirm a **CNAME** was created automatically when adding the Public Hostname.

| Type | Name | Content (example) |
|------|------|---------------------|
| CNAME | `proxmox` | `<tunnel-id>.cfargotunnel.com` |

## 5. Home Assistant — trusted_proxies

When Home Assistant sits behind the tunnel, place `http` settings in **packages**.

→ [homeassistant/packages/http.yaml](../homeassistant/packages/http.yaml) · [http.en.md](../homeassistant/packages/http.en.md)

| Item | Description |
|------|-------------|
| `172.30.33.0/24` | HA OS internal (supervisor/add-on) range |
| `<CLOUDFLARED_LXC_IP>` | cloudflared LXC LAN IP |

Place in `/config/packages/http.yaml` and restart HA. LXC install: [README.en.md](README.en.md)

## 6. Relation to NPM

| Approach | Description |
|----------|-------------|
| Legacy | Cloudflare DNS → public IP → NPM → internal service |
| Tunnel | Cloudflare → cloudflared → internal service (**port forwarding and NPM optional**) |

Do **not** mix NPM and tunnel Hostnames on the same domain — keep DNS and paths consistent.

## 7. Troubleshooting

| Symptom | Action |
|---------|--------|
| Tunnel Offline | On LXC: `systemctl status cloudflared`, reinstall token |
| 502 / connection failure | Public Hostname internal URL/port, LXC → target connectivity |
| Proxmox HTTPS error | Enable **No TLS Verify** |
| HA login / IP error | Add cloudflared LXC IP to `trusted_proxies` |

## 8. Security

- `<TUNNEL_TOKEN>` **grants tunnel control if exposed** — do not store in secrets or git
- Add per-URL auth with Zero Trust **Access policies**
- Do not expose all internal services — register only required Hostnames
