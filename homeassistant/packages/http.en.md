# packages/http.yaml

**Language:** [한국어](http.md) · [English](http.en.md)

Configures the `http` integration so Home Assistant behind a proxy such as [Cloudflare Tunnel](../../cloudflared/tunnel-setup.en.md) correctly recognizes **client IP and scheme (HTTPS)**.

HA path: `/config/packages/http.yaml`

## Prerequisites

- [cloudflared LXC](../../cloudflared/README.en.md) installed and tunnel configured
- `<CLOUDFLARED_LXC_IP>` — cloudflared LXC LAN IP

## Contents

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 172.30.33.0/24
    - <CLOUDFLARED_LXC_IP>
```

| Item | Description |
|------|------|
| `use_x_forwarded_for` | Use real client IP from `X-Forwarded-For` header |
| `172.30.33.0/24` | HA OS **internal (supervisor/add-on)** subnet |
| `<CLOUDFLARED_LXC_IP>` | cloudflared LXC LAN IP (single IP, no `/24`) |

Add other **reverse proxy** IPs (e.g. NPM) to the `trusted_proxies` list.

## Integration

| Doc | Contents |
|------|------|
| [cloudflared/tunnel-setup.en.md](../../cloudflared/tunnel-setup.en.md#5-home-assistant--trusted_proxies) | Tunnel + HA procedure |
| [config-structure.en.md](../config-structure.en.md) | packages·secrets structure |

## Apply

1. Deploy `packages/http.yaml` and set `<CLOUDFLARED_LXC_IP>`
2. **Developer tools → YAML** — check configuration
3. Restart HA if needed
