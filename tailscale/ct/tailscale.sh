#!/usr/bin/env bash
# Tailscale subnet router LXC installer for Proxmox VE.
#
# Interactive (asks for anything not already set):
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/eigger/proxmox-setup/master/tailscale/ct/tailscale.sh)"
#
# Fully unattended one-liner (any var you set is skipped in the wizard):
#   CTID=110 CT_HOSTNAME=tailscale IP_MODE=dhcp ADVERTISE_CIDR=192.168.1.0/24 \
#   AUTHKEY=tskey-auth-xxxxx bash -c "$(curl -fsSL https://raw.githubusercontent.com/eigger/proxmox-setup/master/tailscale/ct/tailscale.sh)"
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
  err "Proxmox VE 호스트에서 실행해야 합니다."
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

echo -e "${CYAN}== Tailscale 서브넷 라우터 LXC 설치 ==${NC}"

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
  err "컨테이너 rootfs를 저장할 storage가 없습니다."
  exit 1
fi
ask ROOTFS_STORAGE "Rootfs storage (options: ${ROOTDIR_STORAGES[*]})" "${ROOTDIR_STORAGES[0]}"

mapfile -t TEMPLATE_STORAGES < <(pvesm status --content vztmpl | awk 'NR>1{print $1}')
if [ ${#TEMPLATE_STORAGES[@]} -eq 0 ]; then
  err "vztmpl를 저장할 storage가 없습니다."
  exit 1
fi
ask TEMPLATE_STORAGE "Template storage (options: ${TEMPLATE_STORAGES[*]})" "${TEMPLATE_STORAGES[0]}"

ask IP_MODE "IPv4 설정 - dhcp 또는 static" "dhcp"
if [ "$IP_MODE" = "static" ]; then
  ask STATIC_IP "  Static IP/CIDR (예: 192.168.1.50/24)" ""
  ask STATIC_GW "  Gateway (예: 192.168.1.1)" ""
  NET_CONFIG="name=eth0,bridge=${BRIDGE},ip=${STATIC_IP},gw=${STATIC_GW},firewall=1"
else
  NET_CONFIG="name=eth0,bridge=${BRIDGE},ip=dhcp,firewall=1"
fi

msg "Debian 12 템플릿 확인 중..."
pveam update >/dev/null 2>&1 || true
TEMPLATE=$(pveam available --section system | awk '/debian-12-standard/{print $2}' | sort -V | tail -1)
if [ -z "$TEMPLATE" ]; then
  err "Debian 12 템플릿을 찾을 수 없습니다."
  exit 1
fi
if ! pveam list "$TEMPLATE_STORAGE" | grep -q "$TEMPLATE"; then
  msg "템플릿 다운로드: $TEMPLATE"
  pveam download "$TEMPLATE_STORAGE" "$TEMPLATE"
fi

msg "LXC $CTID ($CT_HOSTNAME) 생성 중..."
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

msg "LXC 시작 중..."
pct start "$CTID"

msg "네트워크 준비 대기 중..."
for _ in $(seq 1 30); do
  if pct exec "$CTID" -- ip -4 addr show eth0 2>/dev/null | grep -q "inet "; then
    break
  fi
  sleep 2
done
CT_IP=$(pct exec "$CTID" -- bash -c "ip -4 -o addr show eth0 | awk '{print \$4}' | cut -d/ -f1" || true)

msg "Tailscale 설치 중..."
pct exec "$CTID" -- bash -c "apt-get update -qq && apt-get install -y -qq curl ca-certificates >/dev/null"
pct exec "$CTID" -- bash -c "curl -fsSL https://tailscale.com/install.sh | sh >/dev/null"

msg "IP forwarding 활성화 중..."
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
  msg "감지된 LAN 대역: $LAN_CIDR (브리지 $BRIDGE 기준)"
else
  warn "브리지 $BRIDGE 에서 LAN 대역을 자동으로 감지하지 못했습니다."
fi
ask ADVERTISE_CIDR "Advertise-routes CIDR" "$LAN_CIDR"
if [ -z "$ADVERTISE_CIDR" ]; then
  err "advertise-routes 대역이 지정되지 않았습니다. 컨테이너 생성 후 수동으로 'tailscale up --advertise-routes=<CIDR>'를 실행하세요."
fi

ask AUTHKEY "Tailscale auth key (선택, 비워두면 나중에 수동 로그인)" ""

if [ -n "$AUTHKEY" ] && [ -n "$ADVERTISE_CIDR" ]; then
  msg "Tailscale 로그인 및 서브넷 라우터 설정 중..."
  pct exec "$CTID" -- tailscale up --authkey="$AUTHKEY" --advertise-routes="$ADVERTISE_CIDR" --accept-dns=false
else
  warn "auth key가 없어 자동 로그인은 건너뜁니다."
fi

echo
msg "설치 완료: CTID=$CTID, LXC IP=${CT_IP:-확인 필요}"
if [ -z "$AUTHKEY" ]; then
  echo -e "  아래 명령으로 로그인 및 서브넷 라우터 설정을 완료하세요:"
  echo -e "  ${CYAN}pct exec $CTID -- tailscale up --advertise-routes=${ADVERTISE_CIDR:-<LAN_CIDR>}${NC}"
fi
echo -e "  Tailscale 관리자 콘솔(https://login.tailscale.com/admin/machines)에서 이 머신의 advertised route를 ${YELLOW}승인(Approve)${NC}해야 실제로 사용 가능합니다."
