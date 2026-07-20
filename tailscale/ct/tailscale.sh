#!/usr/bin/env bash
# Tailscale subnet router LXC installer for Proxmox VE.
#
# Interactive (asks for anything not already set):
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/eigger/proxmox-setup/master/tailscale/ct/tailscale.sh)"
#
# Fully unattended one-liner (any var you set is skipped in the wizard):
#   CTID=110 CT_HOSTNAME=tailscale TS_HOSTNAME=tailscale IP_MODE=dhcp \
#   ADVERTISE_CIDR=192.168.1.0/24 AUTHKEY=tskey-auth-xxxxx \
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/eigger/proxmox-setup/master/tailscale/ct/tailscale.sh)"
#
# CT_HOSTNAME sets the LXC's own Linux hostname; TS_HOSTNAME sets the device
# name it registers under in the Tailscale admin console (defaults to
# CT_HOSTNAME, so most setups never need to set it separately).
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
msg() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[x]${NC} $1" >&2; }

# Prompts only when the named env var isn't already set, so every value here
# can be supplied up front as an env var to make the whole install one line.
ask() {
  local __var="$1" __label="$2" __default="$3"
  if [ -n "${!__var:-}" ]; then
    return
  fi
  local __reply
  read -rp "$__label [$__default]: " __reply
  printf -v "$__var" '%s' "${__reply:-$__default}"
}

if ! command -v pveversion >/dev/null 2>&1; then
  err "This must be run on a Proxmox VE host."
  exit 1
fi

ip_to_int() {
  local a b c d
  IFS=. read -r a b c d <<< "$1"
  echo $(( (a << 24) + (b << 16) + (c << 8) + d ))
}

int_to_ip() {
  local ui=$1
  printf "%d.%d.%d.%d" $(( (ui >> 24) & 255 )) $(( (ui >> 16) & 255 )) $(( (ui >> 8) & 255 )) $(( ui & 255 ))
}

network_cidr() {
  local ip=$1 prefix=$2
  local ipint mask netint
  ipint=$(ip_to_int "$ip")
  mask=$(( prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF ))
  netint=$(( ipint & mask ))
  echo "$(int_to_ip "$netint")/$prefix"
}

echo -e "${CYAN}== Tailscale subnet router LXC install ==${NC}"

ask CTID "CTID" "$(pvesh get /cluster/nextid)"
# Named CT_HOSTNAME, not HOSTNAME: bash auto-populates $HOSTNAME with the
# Proxmox host's own hostname, which would make `ask` skip this prompt.
ask CT_HOSTNAME "Hostname" "tailscale"
ask CORES "Cores" "1"
ask MEMORY "Memory MB" "512"
ask DISK_SIZE "Disk size GB" "2"
ask BRIDGE "Bridge" "vmbr0"

mapfile -t ROOTDIR_STORAGES < <(pvesm status --content rootdir | awk 'NR>1{print $1}')
if [ ${#ROOTDIR_STORAGES[@]} -eq 0 ]; then
  err "No storage available for container rootfs."
  exit 1
fi
ask ROOTFS_STORAGE "Rootfs storage (options: ${ROOTDIR_STORAGES[*]})" "${ROOTDIR_STORAGES[0]}"

mapfile -t TEMPLATE_STORAGES < <(pvesm status --content vztmpl | awk 'NR>1{print $1}')
if [ ${#TEMPLATE_STORAGES[@]} -eq 0 ]; then
  err "No storage available for vztmpl."
  exit 1
fi
ask TEMPLATE_STORAGE "Template storage (options: ${TEMPLATE_STORAGES[*]})" "${TEMPLATE_STORAGES[0]}"

ask IP_MODE "IPv4 mode - dhcp or static" "dhcp"
if [ "$IP_MODE" = "static" ]; then
  ask STATIC_IP "  Static IP/CIDR (e.g. 192.168.1.50/24)" ""
  ask STATIC_GW "  Gateway (e.g. 192.168.1.1)" ""
  NET_CONFIG="name=eth0,bridge=${BRIDGE},ip=${STATIC_IP},gw=${STATIC_GW},firewall=1"
else
  NET_CONFIG="name=eth0,bridge=${BRIDGE},ip=dhcp,firewall=1"
fi

msg "Checking for the Debian 13 template..."
pveam update >/dev/null 2>&1 || true
TEMPLATE=$(pveam available --section system | awk '/debian-13-standard/{print $2}' | sort -V | tail -1)
if [ -z "$TEMPLATE" ]; then
  err "Could not find a Debian 13 template."
  exit 1
fi
if ! pveam list "$TEMPLATE_STORAGE" | grep -q "$TEMPLATE"; then
  msg "Downloading template: $TEMPLATE"
  pveam download "$TEMPLATE_STORAGE" "$TEMPLATE"
fi

msg "Creating LXC $CTID ($CT_HOSTNAME)..."
pct create "$CTID" "$TEMPLATE_STORAGE:vztmpl/$TEMPLATE" \
  -hostname "$CT_HOSTNAME" \
  -cores "$CORES" \
  -memory "$MEMORY" \
  -swap 512 \
  -rootfs "$ROOTFS_STORAGE:$DISK_SIZE" \
  -net0 "$NET_CONFIG" \
  -features nesting=1 \
  -unprivileged 1 \
  -onboot 1 \
  -ostype debian

# Tailscale needs /dev/net/tun; unprivileged containers don't get it by default.
LXC_CONFIG="/etc/pve/lxc/${CTID}.conf"
cat >> "$LXC_CONFIG" <<EOF
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
EOF

msg "Starting LXC..."
pct start "$CTID"

msg "Waiting for networking..."
for _ in $(seq 1 30); do
  if pct exec "$CTID" -- ip -4 addr show eth0 2>/dev/null | grep -q "inet "; then
    break
  fi
  sleep 2
done
CT_IP=$(pct exec "$CTID" -- bash -c "ip -4 -o addr show eth0 | awk '{print \$4}' | cut -d/ -f1" || true)

msg "Installing Tailscale..."
pct exec "$CTID" -- bash -c "apt-get update -qq && apt-get install -y -qq curl ca-certificates >/dev/null"
pct exec "$CTID" -- bash -c "curl -fsSL https://tailscale.com/install.sh | sh >/dev/null"

msg "Enabling IP forwarding..."
pct exec "$CTID" -- bash -c "cat > /etc/sysctl.d/99-tailscale.conf <<'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sysctl -p /etc/sysctl.d/99-tailscale.conf >/dev/null"

# Derive the LAN subnet from the Proxmox host's own bridge, since the LXC
# is bridged onto the same LAN and this is the range to advertise to Tailscale.
LAN_CIDR=""
if HOST_ADDR=$(ip -4 -o addr show dev "$BRIDGE" 2>/dev/null | awk '{print $4}' | head -1); then
  if [ -n "$HOST_ADDR" ]; then
    HOST_IP=${HOST_ADDR%%/*}
    HOST_PREFIX=${HOST_ADDR##*/}
    LAN_CIDR=$(network_cidr "$HOST_IP" "$HOST_PREFIX")
  fi
fi

if [ -n "$LAN_CIDR" ]; then
  msg "Detected LAN range: $LAN_CIDR (based on bridge $BRIDGE)"
else
  warn "Could not auto-detect the LAN range from bridge $BRIDGE."
fi
ask ADVERTISE_CIDR "Advertise-routes CIDR" "$LAN_CIDR"
if [ -z "$ADVERTISE_CIDR" ]; then
  err "No advertise-routes range given. After the container is created, run 'tailscale up --advertise-routes=<CIDR>' manually."
fi

ask TS_HOSTNAME "Tailscale node name" "$CT_HOSTNAME"
ask AUTHKEY "Tailscale auth key (optional, leave blank to log in manually later)" ""

if [ -n "$AUTHKEY" ] && [ -n "$ADVERTISE_CIDR" ]; then
  msg "Logging into Tailscale and setting up the subnet router..."
  pct exec "$CTID" -- tailscale up --authkey="$AUTHKEY" --advertise-routes="$ADVERTISE_CIDR" --hostname="$TS_HOSTNAME" --accept-dns=false
else
  warn "No auth key given, skipping automatic login."
fi

msg "Setting up Proxmox console root auto-login..."
# Proxmox's Console tab / `pct console` attaches to /dev/console, which
# systemd serves via console-getty.service — not container-getty@N.service
# (that one only covers the pts-based ttyN devices, which pct's console
# feature doesn't use).
pct exec "$CTID" -- bash -c "mkdir -p /etc/systemd/system/console-getty.service.d && cat > /etc/systemd/system/console-getty.service.d/override.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear --keep-baud console 115200,38400,9600 \$TERM
EOF
systemctl daemon-reload && systemctl restart console-getty.service"

echo
msg "Install complete: CTID=$CTID, LXC IP=${CT_IP:-check manually}"
if [ -z "$AUTHKEY" ]; then
  echo -e "  Run this to finish login and subnet router setup:"
  echo -e "  ${CYAN}pct exec $CTID -- tailscale up --advertise-routes=${ADVERTISE_CIDR:-<LAN_CIDR>} --hostname=${TS_HOSTNAME}${NC}"
fi
echo -e "  You must ${YELLOW}approve${NC} this machine's advertised route in the Tailscale admin console (https://login.tailscale.com/admin/machines) before it actually works."
echo -e "  The Proxmox web UI's LXC ${CTID} → Console now logs in as root automatically, no password."
