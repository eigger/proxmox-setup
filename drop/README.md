# Drop

**Language:** [한국어](README.md) · [English](README.en.md)

[Drop](https://github.com/eigger/drop) — 모바일과 PC 간의 쉽고 빠른 파일 전송을 위해 설계된 경량 셀프호스팅 파일 공유 웹 서비스 (Android Web Share Target PWA, 8MB 청크 분할 이어올리기 업로드, 폴더 관리, 휴지통, 다중 선택 zip 다운로드 등 지원).

## 설치

Proxmox VE **LXC** 설치 스크립트:

1. Proxmox 호스트 **Shell**에서 아래 명령 실행
2. 마법사 설정에 따라 LXC 생성

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/eigger/drop/main/proxmox/ct/drop.sh)"
```

설치 후 웹 UI: `http://<DROP_IP>` (기본 포트 **80**)

### 초기 설정

1. 첫 접속 시 사용자 테이블이 비어있으면 **최초 관리자 가입(Bootstrap Admin)** 페이지가 표시됩니다. 이름·이메일·비밀번호를 설정하여 관리자 계정을 생성합니다.
2. 계정 생성 후 로그인하여 관리자 페이지(사용자 추가/관리) 및 파일 공유 기능을 사용합니다.

## 폴더 구조

```
drop/
├── README.md
└── README.en.md
```
