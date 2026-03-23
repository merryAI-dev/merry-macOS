# merry-macOS

MYSC 사무실 macOS 환경에서 로컬로 실행하는 도구 모음입니다.

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
