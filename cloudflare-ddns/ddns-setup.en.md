# Cloudflare DDNS configuration

**Language:** [한국어](ddns-setup.md) · [English](ddns-setup.en.md)

Keeps Cloudflare DNS records aligned when the router or ISP **public IPv4 (·IPv6)** changes. Separate from [Cloudflare Tunnel](../cloudflared/tunnel-setup.en.md); use when you **only need DDNS DNS updates**.

```
Public IP change detected ──► cloudflare-ddns LXC ──► Cloudflare API ──► DNS A/AAAA update
```

## Prerequisites

- **Domain** registered and delegated in Cloudflare
- [cloudflare-ddns LXC](https://community-scripts.org/scripts/cloudflare-ddns) installed

## 1. Cloudflare API token

1. [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens) → **Create Token**
2. Use the **Edit zone DNS** template or manual permissions:
   - Zone → DNS → **Edit**
   - Target zone: your domain only
3. Copy the token — `<CLOUDFLARE_API_TOKEN>` (**do not commit to git or docs**)

Details: [favonia/cloudflare-ddns README](https://github.com/favonia/cloudflare-ddns) — API token permissions

## 2. Install wizard (first run)

The LXC install script prompts interactively:

| Prompt | Example | Description |
|--------|---------|-------------|
| API token | (token value) | Issued in [1. Cloudflare API token](#1-cloudflare-api-token) |
| Domains | `home.example.com,*.example.com` | Comma-separated; wildcards allowed |
| Proxied? | `y` / `n` | Cloudflare **orange cloud** (proxy) on/off |
| IPv6 support? | `y` / `n` | `y` → `IP6_PROVIDER=cloudflare.trace`, `n` → `none` |

The install script writes environment variables to `/etc/systemd/system/cloudflare-ddns.service` and starts the `cloudflare-ddns` service.

## 3. Change settings (after install)

Edit the service unit from the LXC console.

```bash
nano /etc/systemd/system/cloudflare-ddns.service
```

Edit the `Environment=` lines under `[Service]`.

```ini
[Service]
Environment="CLOUDFLARE_API_TOKEN=<CLOUDFLARE_API_TOKEN>"
Environment="DOMAINS=home.example.com,*.example.com"
Environment="PROXIED=false"
Environment="IP6_PROVIDER=none"
```

Apply:

```bash
systemctl daemon-reload
systemctl restart cloudflare-ddns
systemctl status cloudflare-ddns
```

Same as community-scripts guidance: after config changes, run **`systemctl restart cloudflare-ddns`**

## 4. Key environment variables

| Variable | Description | Example |
|----------|-------------|---------|
| `CLOUDFLARE_API_TOKEN` | API token (required) | [1. Cloudflare API token](#1-cloudflare-api-token) |
| `DOMAINS` | FQDNs to update for both A and AAAA (comma-separated) | `ddns.example.com` |
| `IP4_DOMAINS` | **A records only** (IPv4) | `home.example.com` |
| `IP6_DOMAINS` | **AAAA only** (IPv6) | `home.example.com` |
| `PROXIED` | `true` / `false` | Tunnel/hidden IP vs DNS only |
| `IP6_PROVIDER` | IPv6 detection | `none`, `cloudflare.trace`, etc. |

`DOMAINS` and `IP4_DOMAINS`·`IP6_DOMAINS` can be **used together** (additive).  
Full list: [favonia/cloudflare-ddns — environment variables](https://github.com/favonia/cloudflare-ddns)

### Proxied choice

| Value | Use case |
|-------|----------|
| `false` | **DDNS only** — public IP recorded in DNS as-is (dynamic IP exposed) |
| `true` | Via Cloudflare CDN/WAF — hides real IP (common with [Tunnel](../cloudflared/tunnel-setup.en.md)) |

## 5. Verify operation

1. `journalctl -u cloudflare-ddns -f` — check update logs
2. Cloudflare **DNS → Records** — target record IP matches current public IP
3. After public IP change (reboot, line reconnect), confirm automatic update

## 6. Using with Tunnel

| Setup | DDNS | Tunnel |
|-------|------|--------|
| Dynamic public IP + NPM/port forwarding | DDNS sets `home.example.com` → current IP | — |
| Expose services without fixed IP | — | [cloudflared](../cloudflared/tunnel-setup.en.md) Public Hostname |
| Mixed use | **Avoid conflicts** between DDNS records and Tunnel CNAME | Per-Hostname DNS auto-created |

Do not place DDNS A records and Tunnel CNAME on the same hostname.

## 7. Troubleshooting

| Symptom | Action |
|---------|--------|
| API token invalid | Check token permissions (Zone DNS Edit) and zone scope |
| Record not updating | `DOMAINS` spelling, `systemctl status cloudflare-ddns` |
| IPv6 error | Use IPv4 only with `IP6_PROVIDER=none` |
| Settings not applied | `daemon-reload` then `restart` |

## 8. Security

- Keep `CLOUDFLARE_API_TOKEN` only in `cloudflare-ddns.service` — **do not commit to the repo**
- Token should have **least privilege** (that zone’s DNS Edit only)
