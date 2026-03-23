# Printer Studio

사내용 Canon 복합기용 로컬 macOS 앱입니다.

현재 범위:

- PDF 열기
- 서명/도장 PNG/JPG 업로드
- 흰 배경 제거 후 투명 PNG 자산화
- 페이지 위에 서명/도장 배치
- 새 PDF로 저장
- macOS 기본 스캐너 UI 임베드

인쇄는 앱 안에서 하지 않고 저장한 PDF를 별도 하네스로 보내는 구조입니다.

## 요구 사항

- macOS
- Swift 6 / Command Line Tools 이상
- 기존 인쇄 하네스: `/Users/boram/printer-harness/printer_harness.py`
- Canon 큐: `_6l85k35m5_j80`

## 실행

```bash
cd /Users/boram/printer-studio-app
./run_app.sh
```

## 릴리스 빌드와 앱 번들

```bash
cd /Users/boram/printer-studio-app
./scripts/package_app.sh
open dist/PrinterStudio.app
```

## 구조

- `Sources/PrinterStudio/Services/DocumentWorkspace.swift`
  문서 로드, 서명 자산, 배치, 내보내기 흐름
- `Sources/PrinterStudio/Views/DocumentWorkspaceView.swift`
  PDF 편집 UI
- `Sources/PrinterStudio/Views/ScannerPanel.swift`
  macOS 기본 스캔 패널 브리지
