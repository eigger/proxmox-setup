# grocy

[grocy](https://grocy.info/) — 식료품·가사용품 재고, 쇼핑 목록, 레시피·식단을 관리하는 셀프호스트 웹 앱.

## 설치

Proxmox VE **LXC** 설치 스크립트: [grocy — Proxmox VE Helper Scripts](https://community-scripts.org/scripts/grocy)

1. Proxmox 호스트 **Shell**에서 아래 명령 실행
2. 마법사에서 **Default** 또는 **Advanced** 선택 후 LXC 생성

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/grocy.sh)"
```

설치 후 웹 UI: `http://<GROCY_IP>` (기본 포트 **80**)

### 초기 설정

스크립트 기본 계정: `admin` / `admin` — **첫 로그인 후 반드시 비밀번호 변경**

## Home Assistant 연동

| 연동 가이드 | 문서 |
|-------------|------|
| Niimbot 라벨 (grocy Webhook → HA) | [ha-niimbot.md](ha-niimbot.md) |
| hass-niimbot 예시 | [github.com/eigger/hass-niimbot/.../grocy](https://github.com/eigger/hass-niimbot/tree/master/examples/grocy) |
| HA packages·secrets 구조 | [homeassistant/config-structure.md](../homeassistant/config-structure.md) |

## 폴더 구조

```
grocy/
├── README.md
└── ha-niimbot.md            # HA 연동 상세 (Webhook 자동화)
```

HA packages 조합본 없음 — Webhook 자동화는 [ha-niimbot.md](ha-niimbot.md) §2

## 비밀값

관리자 비밀번호·Webhook URL·API 키는 **커밋하지 않습니다**.
