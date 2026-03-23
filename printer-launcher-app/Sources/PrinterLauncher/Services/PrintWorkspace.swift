import AppKit
import Foundation
import PDFKit

enum PrintWorkspaceError: LocalizedError {
    case invalidPDF
    case noSelectedPDF

    var errorDescription: String? {
        switch self {
        case .invalidPDF:
            "유효한 PDF 파일을 열지 못했습니다."
        case .noSelectedPDF:
            "먼저 인쇄할 PDF를 선택하세요."
        }
    }
}

@MainActor
final class PrintWorkspace: ObservableObject {
    @Published private(set) var selectedPDFURL: URL?
    @Published private(set) var pdfDocument: PDFDocument?
    @Published private(set) var previewImage: NSImage?
    @Published var statusMessage = "PDF를 열고 원하는 프리셋으로 바로 인쇄하세요."

    private let printService = PrintService()

    func openPDFPanel() {
        let panel = NSOpenPanel()
        panel.title = "인쇄할 PDF 선택"
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try openPDF(at: url)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func openPDF(at url: URL) throws {
        guard let document = PDFDocument(url: url), document.pageCount > 0 else {
            throw PrintWorkspaceError.invalidPDF
        }

        selectedPDFURL = url
        pdfDocument = document
        previewImage = document.page(at: 0)?.thumbnail(of: CGSize(width: 680, height: 920), for: .mediaBox)
        statusMessage = "\(url.lastPathComponent)을 열었습니다."
    }

    func printSelectedFile(using preset: PrintPreset) {
        do {
            guard let selectedPDFURL else {
                throw PrintWorkspaceError.noSelectedPDF
            }
            let result = try printService.printFile(selectedPDFURL, preset: preset)
            statusMessage = result.isEmpty ? "\(preset.title) 프리셋으로 인쇄 요청을 보냈습니다." : result
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func refreshQueueStatus() {
        do {
            let result = try printService.queueStatus()
            statusMessage = result.isEmpty ? "큐 상태를 확인했습니다." : result
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
