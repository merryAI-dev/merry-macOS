# merry-macOS

MYSC 사무실 macOS 환경에서 로컬로 실행하는 도구 모음입니다.

## 사전 준비 (Prerequisites)

### 필수 설치 항목

| 항목 | 확인 방법 | 설치 방법 |
|------|-----------|-----------|
| **macOS** 13 이상 | `sw_vers` | - |
| **Python 3.10+** | `python3 --version` | [python.org](https://www.python.org) 또는 `brew install python` |
| **Node.js 18+** | `node --version` | [nodejs.org](https://nodejs.org) 또는 `brew install node` |
| **Canon iR-ADV 드라이버** | `/Library/Printers/Canon` 폴더 존재 여부 | [Canon 공식 드라이버 다운로드](https://www.canon-bs.co.kr) |

### Canon 드라이버 설치 확인

```bash
ls /Library/Printers/Canon/CUPS_Printer/Bins/capdftopdl
```

파일이 없으면 Canon iR-ADV CUPS 드라이버를 먼저 설치해야 합니다.

### 양면 인쇄 설정 (최초 1회)

Canon 드라이버 기본값이 단면으로 설정되어 있어 아래 명령을 한 번 실행해야 합니다.

```bash
sudo sed -i '' 's/\*CNNotChangeDuplex: True/*CNNotChangeDuplex: False/' \
  /private/etc/cups/ppd/_6l85k35m5_j80.ppd
```

> **참고**: 프린터 큐를 재설치하면 이 설정이 초기화되므로 다시 실행해야 합니다.

### 프린터 큐 설치 (큐가 없을 때)

```bash
cd printer-harness
python3 printer_harness.py install \
  --printer-uri ipp://10.10.6.100/ipp/print \
  --location "6층복합기" \
  --sudo
```

## 포함된 도구

| 폴더 | 설명 |
|------|------|
| `printer-harness` | Canon iR-ADV 복합기 양면 인쇄 자동화 (Python CLI) |
| `printer-launcher-web` | 인쇄 UI 웹앱 — PDF 드래그앤드롭 후 바로 인쇄 (Node.js) |
| `printer-launcher-app` | 인쇄 런처 macOS 앱 (Swift) |
| `printer-studio-app` | 인쇄 스튜디오 macOS 앱 (Swift) |

## 빠른 시작

### 복합기 웹 런처

```bash
cd printer-launcher-web
npm install
./run_app.sh
# → http://127.0.0.1:4310
```

종료:
```bash
./stop_app.sh
```
