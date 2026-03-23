import SwiftUI

struct PrintWorkspaceView: View {
    @EnvironmentObject private var workspace: PrintWorkspace
    @State private var isTargetingPDFDrop = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                previewPane
                Divider()
                actionPane
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .safeAreaInset(edge: .bottom) {
            statusBar
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button("PDF 열기") {
                workspace.openPDFPanel()
            }
            .buttonStyle(.borderedProminent)

            Button("큐 상태 확인") {
                workspace.refreshQueueStatus()
            }
            .buttonStyle(.bordered)

            Spacer()

            if let selectedPDFURL = workspace.selectedPDFURL {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(selectedPDFURL.lastPathComponent)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(selectedPDFURL.deletingLastPathComponent().path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.white)
    }

    private var previewPane: some View {
        ZStack {
            if let previewImage = workspace.previewImage {
                ScrollView([.vertical, .horizontal]) {
                    VStack(spacing: 20) {
                        Text("첫 페이지 미리보기")
                            .font(.title3.weight(.semibold))
                        Image(nsImage: previewImage)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(maxWidth: 700)
                            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                            .padding(28)
                            .background(.white, in: RoundedRectangle(cornerRadius: 22))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .padding(32)
                }
                .background(Color(nsColor: .controlBackgroundColor))
            } else {
                emptyState
            }
        }
        .dropDestination(for: URL.self) { items, _ in
            handleDroppedPDF(items)
        } isTargeted: { targeted in
            isTargetingPDFDrop = targeted
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 22) {
            Image(systemName: "printer.fill.and.paper.fill")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("PDF 선택 후 바로 인쇄")
                    .font(.system(size: 30, weight: .semibold))
                Text("이 영역에 PDF를 드래그하거나 위의 `PDF 열기` 버튼을 누르세요.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 420)
            }

            Button("PDF 열기") {
                workspace.openPDFPanel()
            }
            .buttonStyle(.borderedProminent)

            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [12, 10]))
                .foregroundStyle(isTargetingPDFDrop ? Color.accentColor : Color.black.opacity(0.18))
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(isTargetingPDFDrop ? Color.accentColor.opacity(0.08) : Color.white)
                )
                .frame(width: 520, height: 280)
                .overlay {
                    VStack(spacing: 12) {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 38, weight: .light))
                        Text(isTargetingPDFDrop ? "놓으면 바로 열립니다" : "여기에 PDF 드래그")
                            .font(.title3.weight(.medium))
                        Text("양면 컬러, 양면 흑백, 2-up 프리셋으로 바로 인쇄합니다.")
                            .foregroundStyle(.secondary)
                    }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var actionPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("빠른 인쇄")
                        .font(.title3.weight(.semibold))
                    VStack(spacing: 12) {
                        ForEach(PrintPreset.allCases) { preset in
                            Button {
                                workspace.printSelectedFile(using: preset)
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.accentColor.opacity(0.12))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: preset.symbolName)
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(Color.accentColor)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(preset.title)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(preset.detail)
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(workspace.selectedPDFURL == nil)
                        }
                    }
                }
                .padding(18)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("사용 흐름")
                        .font(.headline)
                    Text("1. PDF를 엽니다.")
                    Text("2. 양면 컬러/흑백 또는 2-up 프리셋을 누릅니다.")
                    Text("3. 큐 상태가 궁금하면 `큐 상태 확인`을 누릅니다.")
                }
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("연결 정보")
                        .font(.headline)
                    Text("큐: `_6l85k35m5_j80`")
                    Text("하네스: `/Users/boram/printer-harness/printer_harness.py`")
                    Text("프리셋: `global-vendor-default`")
                }
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
            }
            .padding(18)
        }
        .frame(width: 360)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var statusBar: some View {
        HStack {
            Text(workspace.statusMessage)
                .font(.callout)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.white)
    }

    private func handleDroppedPDF(_ items: [URL]) -> Bool {
        guard let url = items.first else { return false }
        guard url.pathExtension.lowercased() == "pdf" else {
            workspace.statusMessage = "PDF 파일만 드롭할 수 있습니다."
            return false
        }

        do {
            try workspace.openPDF(at: url)
            return true
        } catch {
            workspace.statusMessage = error.localizedDescription
            return false
        }
    }
}
