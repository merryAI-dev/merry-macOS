# Printer Launcher Web

Tailwind CSS 기반의 로컬 인쇄 런처입니다.

기능:

- PDF 열기
- PDF 드래그앤드롭
- 브라우저 내 미리보기
- 양면 컬러, 양면 흑백, 2-up, 단면 컬러 인쇄
- 양면/단면 + 컬러/흑백 + 1-up/2-up 맞춤 조합 인쇄
- 맞춤 인쇄 위자드에서 최종 확인 후 인쇄
- 큐 상태 확인

백엔드는 기존 하네스를 그대로 호출합니다.

- 하네스: `/Users/boram/printer-harness/printer_harness.py`
- 큐: `_6l85k35m5_j80`
- 포트: `4310`

## 실행

```bash
cd /Users/boram/printer-launcher-web
npm install
./run_app.sh
```

브라우저가 자동으로 열리지 않으면 `http://127.0.0.1:4310` 으로 접속하면 됩니다.

종료:

```bash
cd /Users/boram/printer-launcher-web
./stop_app.sh
```
