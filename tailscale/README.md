# Tailscale

**Language:** [한국어](README.md) · [English](README.en.md)

[Tailscale](https://tailscale.com/) — WireGuard 기반 메시 VPN. 이 저장소의 스크립트는 전용 LXC를 만들어 **서브넷 라우터(Subnet Router)**로 구성합니다. Tailnet에 연결된 다른 기기가 집 LAN의 사설 IP(예: Proxmox 호스트, HA, NAS 등)에 그대로 접근할 수 있게 해줍니다.

## 설치

Proxmox VE **LXC** 설치 스크립트 (이 저장소 자체 스크립트, community-scripts 기반 아님):

1. Proxmox 호스트 **Shell**에서 아래 명령 실행
2. 마법사 안내에 따라 CTID·리소스·브리지·IP 방식 입력 (기본값 Enter로 진행 가능)
3. LAN 대역(advertise-routes)은 Proxmox 호스트의 브리지(기본 `vmbr0`) IP/CIDR에서 **자동 감지**되어 기본값으로 채워짐 — 단일 서브넷(vmbr0 하나) 환경 기준. VLAN 등 서브넷이 여러 개면 프롬프트에서 직접 수정
4. Tailscale auth key를 입력하면 설치 중 바로 로그인·서브넷 라우터 설정까지 완료, 비워두면 설치 후 `pct exec <CTID> -- tailscale up --advertise-routes=<CIDR>`로 수동 로그인

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/eigger/proxmox-setup/master/tailscale/ct/tailscale.sh)"
```

값을 환경변수로 미리 주면 해당 질문은 건너뛰고, 전부 지정하면 완전 무인(한 줄) 설치가 됩니다:

```bash
CTID=110 HOSTNAME=tailscale IP_MODE=dhcp ADVERTISE_CIDR=192.168.1.0/24 \
AUTHKEY=tskey-auth-xxxxx bash -c "$(curl -fsSL https://raw.githubusercontent.com/eigger/proxmox-setup/master/tailscale/ct/tailscale.sh)"
```

지원하는 변수: `CTID`, `HOSTNAME`, `CORES`, `MEMORY`, `DISK_SIZE`, `BRIDGE`, `ROOTFS_STORAGE`, `TEMPLATE_STORAGE`, `IP_MODE`(`dhcp`/`static`), `STATIC_IP`, `STATIC_GW`, `ADVERTISE_CIDR`, `AUTHKEY`.

### 설치 후 필수: 라우트 승인

Tailscale은 서브넷 라우트를 광고(advertise)해도 **관리자 콘솔에서 승인하기 전까지는 실제로 뚫리지 않습니다.**

1. [Tailscale 관리자 콘솔 → Machines](https://login.tailscale.com/admin/machines) 접속
2. 방금 만든 LXC(hostname 기준) 찾기 → **Edit route settings** → 광고된 서브넷 **Approve**
3. 접근하려는 다른 기기(휴대폰, 노트북 등)에서도 Tailscale 클라이언트의 **Use subnet routes / Accept routes** 옵션이 켜져 있는지 확인

승인·수락이 끝나면 다른 Tailnet 기기에서 LAN 사설 IP(예: `http://192.168.1.50:8123`)로 바로 접근할 수 있습니다. 포트포워딩이나 공인 IP 노출은 필요 없습니다.

## 동작 원리

- LXC는 unprivileged 컨테이너이며, Tailscale 동작에 필요한 `/dev/net/tun` 디바이스를 컨테이너 conf(`/etc/pve/lxc/<CTID>.conf`)에 직접 추가해 통과시킵니다.
- 컨테이너 내부에 `net.ipv4.ip_forward` / `net.ipv6.conf.all.forwarding`을 활성화하여 Tailnet ↔ LAN 간 트래픽을 중계합니다.
- 집 공유기(ISP 라우터)는 전혀 건드리지 않으며, LXC는 게이트웨이 교체가 아니라 **중계자** 역할만 합니다.

## 폴더 구조

```
tailscale/
├── README.md
├── README.en.md
└── ct/
    └── tailscale.sh          # LXC 생성 + Tailscale 설치 + 서브넷 라우터 설정
```

## 비밀값

Tailscale auth key는 **커밋하지 않으며**, 설치 스크립트 실행 시 프롬프트로만 입력합니다.
