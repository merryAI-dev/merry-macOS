# Printer Launcher

사내용 Canon 복합기 전용 로컬 macOS 인쇄 앱입니다.

현재 범위:

- PDF 열기
- PDF 드래그앤드롭
- 첫 페이지 미리보기
- 양면 컬러 인쇄
- 양면 흑백 인쇄
- 2-up 인쇄
- 큐 상태 확인

기존 하네스를 그대로 사용합니다.

- 하네스: `/Users/boram/printer-harness/printer_harness.py`
- 큐: `_6l85k35m5_j80`
- 프리셋: `global-vendor-default`

## 실행

```bash
cd /Users/boram/printer-launcher-app
./run_app.sh
```

## 릴리스 빌드와 앱 번들

```bash
cd /Users/boram/printer-launcher-app
./scripts/package_app.sh
open dist/PrinterLauncher.app
```
