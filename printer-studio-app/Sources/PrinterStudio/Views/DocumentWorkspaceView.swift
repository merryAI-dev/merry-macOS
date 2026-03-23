import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct DocumentWorkspaceView: View {
    @EnvironmentObject private var workspace: DocumentWorkspace

    @State private var isTargetingPDFDrop = false
    @State private var lastError: String?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HStack(spacing: 0) {
                sidebar
                Divider()
                editor
                Divider()
                inspector
            }
        }
        .alert("작업 실패", isPresented: Binding(
            get: { lastError != nil },
            set: { if !$0 { lastError = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(lastError ?? "알 수 없는 오류")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button("PDF 열기") {
                openPDFPanel()
            }
            .buttonStyle(.borderedProminent)

            Button("PDF 업로드") {
                openPDFPanel()
            }
            .buttonStyle(.bordered)

            Button("서명/도장 추가") {
                openStampPanel()
            }
            .buttonStyle(.bordered)

            Toggle("흰 배경 제거", isOn: $workspace.removeWhiteBackgroundOnImport)
                .toggleStyle(.switch)
                .frame(maxWidth: 180)

            Button("현재 페이지에 올리기") {
                runCatching {
                    try workspace.addSelectedStampToCurrentPage()
                }
            }
            .buttonStyle(.bordered)
            .disabled(workspace.pageCount == 0 || workspace.selectedAssetID == nil)

            Spacer()

            Button("PDF 저장") {
                runCatching {
                    _ = try workspace.exportSignedCopy(interactive: true)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(workspace.pageCount == 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.98, blue: 1.0), Color(red: 0.98, green: 0.97, blue: 0.94)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox("빠른 시작") {
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            openPDFPanel()
                        } label: {
                            Label("PDF 업로드", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Text("PDF 파일을 중앙 캔버스에 드래그해도 바로 열립니다.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("페이지") {
                    if workspace.pageCount == 0 {
                        Text("PDF를 열면 페이지 썸네일이 표시됩니다.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(0..<workspace.pageCount, id: \.self) { index in
                                pageRow(index: index)
                            }
                        }
                    }
                }

                GroupBox("서명/도장 자산") {
                    if workspace.stampAssets.isEmpty {
                        Text("PNG/JPG를 추가하면 개인 도장함처럼 쓸 수 있습니다.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(workspace.stampAssets) { asset in
                                stampRow(asset)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 300)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var editor: some View {
        ZStack {
            if let pageImage = workspace.previewImage(for: workspace.selectedPageIndex, maxDimension: 1280), workspace.pageCount > 0 {
                PDFCanvasView(pageImage: pageImage)
                    .padding(26)
                    .background(Color(red: 0.93, green: 0.94, blue: 0.96))
            } else {
                emptyEditorState
            }
        }
        .dropDestination(for: URL.self) { items, _ in
            handleDroppedPDFs(items)
        } isTargeted: { targeted in
            isTargetingPDFDrop = targeted
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyEditorState: some View {
        VStack(spacing: 22) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("PDF 열기 또는 업로드")
                    .font(.system(size: 28, weight: .semibold))
                Text("PDF 파일을 선택하거나 이 영역에 드래그하면 바로 문서를 엽니다.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 420)
            }

            HStack(spacing: 12) {
                Button("PDF 열기") {
                    openPDFPanel()
                }
                .buttonStyle(.borderedProminent)

                Button("PDF 업로드") {
                    openPDFPanel()
                }
                .buttonStyle(.bordered)
            }

            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [12, 10])
                )
                .foregroundStyle(isTargetingPDFDrop ? Color.accentColor : Color.secondary.opacity(0.4))
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(isTargetingPDFDrop ? Color.accentColor.opacity(0.10) : Color.white.opacity(0.78))
                )
                .frame(width: 520, height: 280)
                .overlay {
                    VStack(spacing: 12) {
                        Image(systemName: "tray.and.arrow.down")
                            .font(.system(size: 38, weight: .light))
                        Text(isTargetingPDFDrop ? "놓으면 PDF를 엽니다" : "여기에 PDF 드래그")
                            .font(.title3.weight(.medium))
                        Text("사인/도장 이미지는 문서를 연 뒤에 추가합니다.")
                            .foregroundStyle(.secondary)
                    }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.94, green: 0.95, blue: 0.98))
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox("선택한 도장") {
                    if let assetID = workspace.selectedAssetID, let asset = workspace.asset(for: assetID) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(asset.name)
                                .font(.headline)
                            if let image = workspace.image(for: asset.id) {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 110)
                                    .frame(maxWidth: .infinity)
                                    .padding(8)
                                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                            }
                            Text("현재 페이지에 올리기 버튼으로 중앙 배치합니다.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("좌측 자산 목록에서 서명/도장을 하나 선택하세요.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                GroupBox("배치 편집") {
                    if let placement = workspace.selectedPlacement {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("\(placement.pageIndex + 1)페이지에 배치됨")
                                .font(.callout)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading) {
                                Text("크기")
                                Slider(
                                    value: Binding(
                                        get: { Double(placement.normalizedWidth) },
                                        set: { workspace.updateSelectedPlacementWidth(CGFloat($0)) }
                                    ),
                                    in: 0.08...0.6
                                )
                            }

                            VStack(alignment: .leading) {
                                Text("회전")
                                Slider(
                                    value: Binding(
                                        get: { Double(placement.rotationDegrees) },
                                        set: { workspace.updateSelectedPlacementRotation(CGFloat($0)) }
                                    ),
                                    in: -180...180
                                )
                            }

                            VStack(alignment: .leading) {
                                Text("투명도")
                                Slider(
                                    value: Binding(
                                        get: { placement.opacity },
                                        set: { workspace.updateSelectedPlacementOpacity($0) }
                                    ),
                                    in: 0.35...1.0
                                )
                            }

                            Button("선택한 도장 삭제", role: .destructive) {
                                workspace.deleteSelectedPlacement()
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Text("캔버스에서 도장을 클릭하면 크기, 회전, 투명도를 조절할 수 있습니다.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                GroupBox("빠른 안내") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. PDF를 엽니다.")
                        Text("2. 서명 PNG/JPG를 추가합니다.")
                        Text("3. 페이지 중앙에 올린 뒤 드래그로 배치합니다.")
                        Text("4. 저장한 뒤 인쇄는 별도 하네스로 진행합니다.")
                    }
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func pageRow(index: Int) -> some View {
        Button {
            workspace.selectedPageIndex = index
            workspace.selectPlacement(nil)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                if let preview = workspace.previewImage(for: index, maxDimension: 200) {
                    Image(nsImage: preview)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                        .background(.white, in: RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                }
                Text("페이지 \(index + 1)")
                    .font(.headline)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(workspace.selectedPageIndex == index ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.7))
            )
        }
        .buttonStyle(.plain)
    }

    private func stampRow(_ asset: StampAsset) -> some View {
        Button {
            workspace.selectedAssetID = asset.id
        } label: {
            HStack(spacing: 12) {
                if let image = workspace.image(for: asset.id) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 56)
                        .padding(8)
                        .background(.white, in: RoundedRectangle(cornerRadius: 12))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(asset.name)
                        .font(.headline)
                    Text("\(Int(asset.imageSize.width)) x \(Int(asset.imageSize.height))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(workspace.selectedAssetID == asset.id ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.65))
            )
        }
        .buttonStyle(.plain)
    }

    private func handleDroppedPDFs(_ items: [URL]) -> Bool {
        guard let url = items.first else { return false }
        let extensionLowercased = url.pathExtension.lowercased()
        guard extensionLowercased == "pdf" else {
            lastError = "PDF 파일만 이 영역에 드롭할 수 있습니다."
            return false
        }

        runCatching {
            try workspace.openDocument(at: url)
        }
        return true
    }

    private func openPDFPanel() {
        let panel = NSOpenPanel()
        panel.title = "PDF 열기"
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        runCatching {
            try workspace.openDocument(at: url)
        }
    }

    private func openStampPanel() {
        let panel = NSOpenPanel()
        panel.title = "서명 또는 도장 이미지 추가"
        panel.allowedContentTypes = [.png, .jpeg, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        runCatching {
            try workspace.importStamp(at: url)
        }
    }

    private func runCatching(_ operation: () throws -> Void) {
        do {
            try operation()
        } catch {
            lastError = error.localizedDescription
        }
    }
}
