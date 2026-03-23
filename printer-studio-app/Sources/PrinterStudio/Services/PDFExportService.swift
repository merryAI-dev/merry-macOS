import AppKit
import Foundation
import PDFKit

enum PDFExportError: LocalizedError {
    case noPages
    case contextCreationFailed
    case missingPage(index: Int)

    var errorDescription: String? {
        switch self {
        case .noPages:
            "내보낼 PDF 페이지가 없습니다."
        case .contextCreationFailed:
            "PDF 저장 컨텍스트를 만들지 못했습니다."
        case .missingPage(let index):
            "\(index + 1)페이지를 읽지 못했습니다."
        }
    }
}

struct PDFExportService {
    func export(
        document: PDFDocument,
        placements: [StampPlacement],
        assets: [UUID: StampAsset],
        imageProvider: (UUID) -> NSImage?,
        destinationURL: URL
    ) throws -> URL {
        guard document.pageCount > 0 else {
            throw PDFExportError.noPages
        }

        var initialBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(destinationURL as CFURL, mediaBox: &initialBox, nil) else {
            throw PDFExportError.contextCreationFailed
        }

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else {
                throw PDFExportError.missingPage(index: pageIndex)
            }

            let pageBounds = page.bounds(for: .mediaBox)
            let pageInfo = [kCGPDFContextMediaBox as String: pageBounds] as CFDictionary
            context.beginPDFPage(pageInfo)
            page.draw(with: .mediaBox, to: context)
            context.interpolationQuality = .high

            for placement in placements where placement.pageIndex == pageIndex {
                guard
                    let asset = assets[placement.assetID],
                    let image = imageProvider(placement.assetID),
                    let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
                else {
                    continue
                }

                let normalizedRect = placement.normalizedRect(assetSize: asset.imageSize, pageSize: pageBounds.size)
                let drawRect = CGRect(
                    x: normalizedRect.minX * pageBounds.width,
                    y: normalizedRect.minY * pageBounds.height,
                    width: normalizedRect.width * pageBounds.width,
                    height: normalizedRect.height * pageBounds.height
                )

                context.saveGState()
                context.setAlpha(CGFloat(placement.opacity))
                context.translateBy(x: drawRect.midX, y: drawRect.midY)
                context.rotate(by: placement.rotationDegrees * .pi / 180)
                context.draw(
                    cgImage,
                    in: CGRect(
                        x: -drawRect.width / 2,
                        y: -drawRect.height / 2,
                        width: drawRect.width,
                        height: drawRect.height
                    )
                )
                context.restoreGState()
            }

            context.endPDFPage()
        }

        context.closePDF()
        return destinationURL
    }
}
