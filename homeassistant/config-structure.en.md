# Home Assistant — Configuration structure (packages)

**Language:** [한국어](config-structure.md) · [English](config-structure.en.md)

The HA instance `/config` splits feature YAML into a **`packages/` folder**. Keep `configuration.yaml` minimal; add REST commands, automations, scripts, etc. in package files.

Official: [Packages](https://www.home-assistant.io/docs/configuration/packages/)

## Documentation hierarchy (this repository)

| Layer | Path | Role |
|----|------|------|
| **LXC/VM README** | `lubelogger/README.md`, `traccar/README.md` … | community-scripts install, ports, HA **links** |
| **Integration details** | `*/ha-*.md`, `cloudflared/tunnel-setup.md` | API, automations, webhooks, LXC↔HA flow |
| **packages** | `homeassistant/packages/*.yaml` | **Single source** of YAML to copy into HA |

- LXC READMEs do **not** duplicate full YAML blocks.
- `ha-*.md` files do **not** repeat the same YAML as packages; link to packages instead.
- Automations, scripts, and add-on settings may exist only in `ha-*.md` until moved into packages.

## Writing tone (unified rules)

| Doc type | Opening | Required sections |
|-----------|------|-----------|
| **LXC/VM README** | `[Product](URL) — one-line role.` | `## Installation` → `## Home Assistant integration` (if applicable) → `## Folder structure` → `## Secrets` |
| **packages/*.md** | One-line feature + `HA path: /config/packages/...` | `## Prerequisites` → body → `## Integration` (optional) → `## Apply` |
| **ha-*.md** | One-line feature + README·packages links | `## Environment (placeholders)` → `## 1.` … → troubleshooting·security |

- **Placeholders:** `<LUBELOGGER_IP>` format (uppercase snake)
- **Tables:** simple 2–3 columns; do not use `:---` alignment rows
- **Tone:** technical documentation style; avoid colloquial, exclamatory, or tutorial voice
- **YAML:** settings in packages are not duplicated in `ha-*.md`; link instead
- **Internal links:** anchor URLs (`#section`); avoid `§` notation

## Multilingual (i18n)

- **Korean:** default filenames (`README.md`, `ha-*.md`, …)
- **English:** sibling `*.en.md` in the same folder (e.g. `README.en.md`, `ha-rest-command.en.md`)
- **YAML:** `homeassistant/packages/*.yaml` is the **single language-neutral source** — not duplicated per locale
- Each doc has a **Language** line under H1 to switch Korean · English

## configuration.yaml (minimal)

```yaml
homeassistant:
  packages: !include_dir_named packages
```

`!include_dir_named` — each **filename (without extension)** under `packages/` becomes the package name.  
Example: `packages/lubelogger.yaml` → package key `lubelogger`

## HA instance directory

```
/config/
├── configuration.yaml       # packages one-liner (+ default_config etc.)
├── secrets.yaml             # secrets (excluded from git)
└── packages/
    ├── lubelogger.yaml      # LubeLogger REST·automations
    ├── traccar.yaml         # Traccar REST·automations
    ├── http.yaml            # trusted_proxies (Tunnel·proxy)
    ├── opinet.yaml          # Opinet fuel price REST
    ├── tasmota.yaml         # Athom IR Remote MQTT
    ├── tmap.yaml            # SK TMAP route guidance
    ├── wol.yaml             # Wake-on-LAN
    ├── recorder.yaml        # Recorder·external DB
    └── …
```

After configuration changes, apply via **Developer tools → Check YAML configuration** or restart.

## Package file example

One file groups `rest_command`, `automation`, `script`, `rest`, etc. for a topic.

Short integration settings such as `rest_command` and `rest` live in [packages/](packages/) per file. Long scenarios like OBD automations stay in service docs such as [lubelogger/ha-rest-command.en.md](../lubelogger/ha-rest-command.en.md); add `automation:`·`script:` to the same package file later if needed.

### Keys you can put in a package (examples)

| Key | Purpose |
|----|------|
| `rest_command` | LubeLogger, Traccar API |
| `rest` | Opinet price sensors |
| `mqtt` | Tasmota IR sensors·buttons |
| `switch` | Wake-on-LAN |
| `recorder` | History DB·purge |
| `automation` | Location, fuel, label printing, etc. |
| `script` | grocy amount-based fueling |
| `http` | `trusted_proxies` (Cloudflared) |

## This repository ↔ HA `/config`

| HA `packages/` | This repo | Integration docs |
|----------------|---------|-----------|
| `http.yaml` | [packages/http.yaml](packages/http.yaml) | [cloudflared/](../cloudflared/tunnel-setup.en.md) |
| `opinet.yaml` | [packages/opinet.yaml](packages/opinet.yaml) | [lubelogger/ha-fuel-opinet.en.md](../lubelogger/ha-fuel-opinet.en.md) |
| `lubelogger.yaml` | [packages/lubelogger.yaml](packages/lubelogger.yaml) | [lubelogger/ha-rest-command.en.md](../lubelogger/ha-rest-command.en.md) |
| `tasmota.yaml` | [packages/tasmota.yaml](packages/tasmota.yaml) | [packages/tasmota.en.md](packages/tasmota.en.md) |
| `tmap.yaml` | [packages/tmap.yaml](packages/tmap.yaml) | [packages/tmap.en.md](packages/tmap.en.md) |
| `traccar.yaml` | [packages/traccar.yaml](packages/traccar.yaml) | [traccar/ha-rest-command.en.md](../traccar/ha-rest-command.en.md) |
| `wol.yaml` | [packages/wol.yaml](packages/wol.yaml) | [packages/wol.en.md](packages/wol.en.md) |
| `recorder.yaml` | [packages/recorder.yaml](packages/recorder.yaml) | [packages/recorder.en.md](packages/recorder.en.md) |

Service-specific **detailed YAML and explanations** live in each app folder (`lubelogger/`, `traccar/` …); `homeassistant/packages/` holds **combined snippets** to deploy in HA.

## secrets.yaml

Secrets only. Package YAML references them with `!secret`.

```yaml
lubelogger_username: "<LUBELOGGER_USER>"
lubelogger_password: "<LUBELOGGER_PASSWORD>"
opinet_nanuri_url: "https://www.opinet.co.kr/api/detailById.do?code=<API>&id=<주유소ID>&out=json"
tmap_api_key: "<TMAP_APP_KEY>"
recorder_db_url: "mysql://<USER>:<PASS>@<DB_HOST>:3306/homeassistant?charset=utf8mb4"
```

**Do not commit to git.**

## Planned additions

- LubeLogger·Traccar automation·script packages consolidation
- File Editor / Studio Code Server `/config` sync·backup method (if needed)
