# Printer Harness

macOS에 이미 설치된 Canon 드라이버와 CUPS 명령을 감싸서 `설치 + 양면 인쇄`를 자동화하는 작은 CLI입니다.

이 Harness는 복합기 패널의 양면 복사 버튼 자체를 고치는 도구는 아닙니다. 대신 다음 흐름을 자동화합니다.

- 프린터 큐 재설치
- 기본 양면 인쇄 옵션 고정
- 기존 macOS 인쇄 프리셋에서 인증 관련 옵션 재사용
- PDF/문서를 양면으로 바로 전송

현재 Mac에서 확인한 기반은 다음과 같습니다.

- Canon 드라이버 경로: `/Library/Printers/Canon`
- Canon C3826 PPD: `/Library/Printers/PPDs/Contents/Resources/CNPZUIRAC3826ZU.ppd.gz`
- 저장된 macOS 프리셋: `~/Library/Preferences/com.apple.print.custompresets*.plist`

## 빠른 사용

프리셋 확인:

```bash
python3 printer_harness.py inspect-preset
```

설치 명령 미리보기:

```bash
python3 printer_harness.py install \
  --printer-uri ipp://PRINTER_IP/ipp/print \
  --location "6층복합기" \
  --sudo \
  --dry-run
```

실제 설치:

```bash
python3 printer_harness.py install \
  --printer-uri ipp://PRINTER_IP/ipp/print \
  --location "6층복합기" \
  --sudo
```

양면 인쇄:

```bash
python3 printer_harness.py print ~/Downloads/report_print.pdf
```

단면으로 강제:

```bash
python3 printer_harness.py print ~/Downloads/report_print.pdf --duplex one-sided
```

추가 옵션 전달:

```bash
python3 printer_harness.py print ~/Downloads/report_print.pdf \
  --option InputSlot=Auto \
  --option Resolution=600
```

## 동작 방식

기본 동작은 안전한 범위의 기존 프리셋만 재사용합니다.

- 양면 관련: `CNDuplex`, `BindEdge`, `sides`
- 인증 관련: `CNAuthenticate`, `CNUseJobAccount`, `CNJobAccount`, `CNUseUsrManagement`, `CNUsrName`, `CNUsrPassword`
- 일부 출력 관련: `InputSlot`, `MediaType`, `OutputBin`, `Resolution`

프리셋에 `number-up=2` 같은 레이아웃 옵션이 들어 있어도 기본적으로는 자동 적용하지 않습니다. 그 옵션까지 모두 재사용하려면 `--apply-all-preset-options`를 사용하면 됩니다.

## 주의

- `install` 단계의 `lpadmin`은 대체로 관리자 권한이 필요합니다.
- 실제 프린터 URI는 사내 장비 주소에 맞게 넣어야 합니다.
- 장비가 진짜로 양면 인쇄 유닛이 없거나 고장난 경우, 이 Harness는 하드웨어 한계를 우회하지는 못합니다.
- 다만 복합기의 “양면 복사” 기능이 막혀 있어도 PDF를 확보할 수 있으면 “양면 인쇄” 흐름으로 대체하는 데는 유효합니다.

## 테스트

```bash
python3 -m unittest discover -s tests
```
