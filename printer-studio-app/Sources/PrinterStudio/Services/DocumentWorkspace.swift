import AppKit
import Foundation
import PDFKit

enum DocumentWorkspaceError: LocalizedError {
    case invalidDocument
    case noDocument
    case noSelectedAsset
    case savePanelFailed

    var errorDescription: String? {
        switch self {
        case .invalidDocument:
            "PDF 문서를 열지 못했습니다."
        case .noDocument:
            "먼저 PDF 문서를 여세요."
        case .noSelectedAsset:
            "서명 또는 도장 이미지를 먼저 선택하세요."
        case .savePanelFailed:
            "저장 위치를 선택하지 못했습니다."
        }
    }
}

@MainActor
final class DocumentWorkspace: ObservableObject {
    @Published private(set) var document: PDFDocument?
    @Published private(set) var documentURL: URL?
    @Published private(set) var stampAssets: [StampAsset] = []
    @Published private(set) var placements: [StampPlacement] = []
    @Published var selectedPageIndex = 0
    @Published var selectedAssetID: UUID?
    @Published var selectedPlacementID: UUID?
    @Published var statusMessage = "PDF를 열거나 스캔 후 불러오면 바로 서명/도장과 인쇄가 가능합니다."
    @Published var lastExportURL: URL?
    @Published var removeWhiteBackgroundOnImport = true

    private let imageProcessor = ImageStampProcessor()
    private let exportService = PDFExportService()
    private let printService = PrintService()

    private var pagePreviewCache: [String: NSImage] = [:]
    private var assetImageCache: [UUID: NSImage] = [:]

    var pageCount: Int { document?.pageCount ?? 0 }

    var selectedPlacement: StampPlacement? {
        guard let selectedPlacementID else { return nil }
        return placements.first { $0.id == selectedPlacementID }
    }

    func asset(for id: UUID) -> StampAsset? {
        stampAssets.first { $0.id == id }
    }

    func image(for id: UUID) -> NSImage? {
        if let cached = assetImageCache[id] {
            return cached
        }
        guard let asset = asset(for: id), let image = NSImage(contentsOf: asset.fileURL) else {
            return nil
        }
        assetImageCache[id] = image
        return image
    }

    func openDocument(at url: URL) throws {
        let resolvedURL: URL
        if PDFDocument(url: url) != nil {
            resolvedURL = url
        } else if let image = NSImage(contentsOf: url) {
            resolvedURL = try convertImageDocumentToPDF(image, sourceURL: url)
        } else {
            throw DocumentWorkspaceError.invalidDocument
        }
        guard let pdf = PDFDocument(url: resolvedURL) else {
            throw DocumentWorkspaceError.invalidDocument
        }

        document = pdf
        documentURL = resolvedURL
        selectedPageIndex = 0
        selectedPlacementID = nil
        placements.removeAll()
        pagePreviewCache.removeAll()
        lastExportURL = nil
        if resolvedURL == url {
            statusMessage = "\(url.lastPathComponent)을 열었습니다."
        } else {
            statusMessage = "\(url.lastPathComponent)을 PDF로 변환해 열었습니다."
        }
    }

    func importStamp(at url: URL) throws {
        let asset = try imageProcessor.importStamp(from: url, removeWhiteBackground: removeWhiteBackgroundOnImport)
        stampAssets.insert(asset, at: 0)
        if let image = NSImage(contentsOf: asset.fileURL) {
            assetImageCache[asset.id] = image
        }
        selectedAssetID = asset.id
        statusMessage = "\(asset.name) 이미지를 도장 자산으로 추가했습니다."
    }

    func addSelectedStampToCurrentPage() throws {
        guard document != nil else { throw DocumentWorkspaceError.noDocument }
        guard let selectedAssetID else { throw DocumentWorkspaceError.noSelectedAsset }
        guard let asset = asset(for: selectedAssetID) else { throw DocumentWorkspaceError.noSelectedAsset }

        let pageSize = sizeForPage(at: selectedPageIndex)
        let placement = StampPlacement(assetID: selectedAssetID, pageIndex: selectedPageIndex)
            .clamped(assetSize: asset.imageSize, pageSize: pageSize)

        placements.append(placement)
        selectedPlacementID = placement.id
        statusMessage = "\(selectedPageIndex + 1)페이지에 \(asset.name)을 배치했습니다."
    }

    func deleteSelectedPlacement() {
        guard let selectedPlacementID else { return }
        placements.removeAll { $0.id == selectedPlacementID }
        self.selectedPlacementID = nil
        statusMessage = "선택한 서명/도장을 제거했습니다."
    }

    func placementsForSelectedPage() -> [StampPlacement] {
        placements.filter { $0.pageIndex == selectedPageIndex }
    }

    func updateSelectedPlacementWidth(_ newWidth: CGFloat) {
        updateSelectedPlacement { $0.normalizedWidth = newWidth }
    }

    func updateSelectedPlacementRotation(_ newRotation: CGFloat) {
        updateSelectedPlacement { $0.rotationDegrees = newRotation }
    }

    func updateSelectedPlacementOpacity(_ newOpacity: Double) {
        updateSelectedPlacement { $0.opacity = newOpacity }
    }

    func movePlacement(_ id: UUID, from origin: StampPlacement, translation: CGSize, canvasSize: CGSize) {
        guard let index = placements.firstIndex(where: { $0.id == id }) else { return }
        guard let asset = asset(for: origin.assetID) else { return }

        let pageWidth = max(canvasSize.width, 1)
        let pageHeight = max(canvasSize.height, 1)

        var updated = origin
        updated.centerX = origin.centerX + (translation.width / pageWidth)
        updated.centerY = origin.centerY - (translation.height / pageHeight)
        updated = updated.clamped(assetSize: asset.imageSize, pageSize: sizeForPage(at: origin.pageIndex))

        placements[index] = updated
        selectedPlacementID = id
    }

    func selectPlacement(_ id: UUID?) {
        selectedPlacementID = id
    }

    func previewImage(for pageIndex: Int, maxDimension: CGFloat) -> NSImage? {
        guard let document, let page = document.page(at: pageIndex) else { return nil }
        let cacheKey = "\(pageIndex)-\(Int(maxDimension.rounded()))"
        if let cached = pagePreviewCache[cacheKey] {
            return cached
        }

        let pageSize = page.bounds(for: .mediaBox).size
        let aspectRatio = max(pageSize.height / max(pageSize.width, 1), 0.1)
        let targetSize = CGSize(width: maxDimension, height: maxDimension * aspectRatio)
        let image = page.thumbnail(of: targetSize, for: .mediaBox)
        pagePreviewCache[cacheKey] = image
        return image
    }

    func sizeForPage(at pageIndex: Int) -> CGSize {
        guard let page = document?.page(at: pageIndex) else {
            return CGSize(width: 612, height: 792)
        }
        return page.bounds(for: .mediaBox).size
    }

    func exportSignedCopy(interactive: Bool) throws -> URL {
        guard let document else { throw DocumentWorkspaceError.noDocument }

        let destinationURL: URL
        if interactive {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = suggestedExportName()
            panel.allowedContentTypes = [.pdf]
            panel.canCreateDirectories = true
            panel.directoryURL = documentURL?.deletingLastPathComponent() ?? AppPaths.exportsDirectory
            guard panel.runModal() == .OK, let selectedURL = panel.url else {
                throw DocumentWorkspaceError.savePanelFailed
            }
            destinationURL = selectedURL
        } else {
            destinationURL = AppPaths.exportsDirectory.appendingPathComponent(suggestedExportName())
        }

        let assetIndex = Dictionary(uniqueKeysWithValues: stampAssets.map { ($0.id, $0) })
        let exportedURL = try exportService.export(
            document: document,
            placements: placements,
            assets: assetIndex,
            imageProvider: { [weak self] id in self?.image(for: id) },
            destinationURL: destinationURL
        )

        lastExportURL = exportedURL
        statusMessage = "\(exportedURL.lastPathComponent) 저장 완료"
        return exportedURL
    }

    func printCurrentDocument(using preset: PrintPreset) throws {
        let printableURL: URL
        if placements.isEmpty, let documentURL {
            printableURL = documentURL
        } else {
            printableURL = try exportSignedCopy(interactive: false)
        }

        let output = try printService.printFile(printableURL, preset: preset)
        if output.isEmpty {
            statusMessage = "\(preset.title) 프리셋으로 인쇄 요청을 보냈습니다."
        } else {
            statusMessage = output
        }
    }

    private func updateSelectedPlacement(_ mutation: (inout StampPlacement) -> Void) {
        guard let selectedPlacementID, let index = placements.firstIndex(where: { $0.id == selectedPlacementID }) else {
            return
        }
        guard let asset = asset(for: placements[index].assetID) else { return }

        var updated = placements[index]
        mutation(&updated)
        updated = updated.clamped(assetSize: asset.imageSize, pageSize: sizeForPage(at: updated.pageIndex))
        placements[index] = updated
    }

    private func suggestedExportName() -> String {
        let baseName = documentURL?.deletingPathExtension().lastPathComponent ?? "signed-document"
        return "\(baseName)-signed.pdf"
    }

    private func convertImageDocumentToPDF(_ image: NSImage, sourceURL: URL) throws -> URL {
        let pdf = PDFDocument()
        guard let page = PDFPage(image: image) else {
            throw DocumentWorkspaceError.invalidDocument
        }
        pdf.insert(page, at: 0)

        let outputURL = AppPaths.exportsDirectory.appendingPathComponent(
            "\(sourceURL.deletingPathExtension().lastPathComponent)-converted.pdf"
        )
        guard pdf.write(to: outputURL) else {
            throw DocumentWorkspaceError.invalidDocument
        }
        return outputURL
    }
}
