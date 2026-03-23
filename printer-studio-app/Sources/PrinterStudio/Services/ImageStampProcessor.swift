import AppKit
import Foundation

enum ImageStampProcessorError: LocalizedError {
    case invalidImage
    case bitmapConversionFailed
    case pngEncodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            "이미지 파일을 불러오지 못했습니다."
        case .bitmapConversionFailed:
            "이미지를 편집 가능한 비트맵으로 변환하지 못했습니다."
        case .pngEncodingFailed:
            "PNG 변환에 실패했습니다."
        }
    }
}

struct ImageStampProcessor {
    func importStamp(from sourceURL: URL, removeWhiteBackground: Bool) throws -> StampAsset {
        guard let image = NSImage(contentsOf: sourceURL) else {
            throw ImageStampProcessorError.invalidImage
        }

        let bitmap = try bitmapRep(for: image)
        let processed = removeWhiteBackground ? removeWhiteBackgroundPixels(in: bitmap) : bitmap
        guard let pngData = processed.representation(using: .png, properties: [:]) else {
            throw ImageStampProcessorError.pngEncodingFailed
        }

        let fileName = "\(UUID().uuidString).png"
        let destinationURL = AppPaths.stampDirectory.appendingPathComponent(fileName)
        try pngData.write(to: destinationURL, options: .atomic)

        return StampAsset(
            name: sourceURL.deletingPathExtension().lastPathComponent,
            fileURL: destinationURL,
            imageSize: CGSize(width: processed.pixelsWide, height: processed.pixelsHigh)
        )
    }

    private func bitmapRep(for image: NSImage) throws -> NSBitmapImageRep {
        var proposedRect = CGRect(origin: .zero, size: image.size)
        if let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) {
            return NSBitmapImageRep(cgImage: cgImage)
        }

        guard
            let tiffData = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiffData)
        else {
            throw ImageStampProcessorError.bitmapConversionFailed
        }
        return rep
    }

    private func removeWhiteBackgroundPixels(in bitmap: NSBitmapImageRep) -> NSBitmapImageRep {
        guard let copy = bitmap.copy() as? NSBitmapImageRep else {
            return bitmap
        }

        let threshold: CGFloat = 0.94
        let fadeStart: CGFloat = 0.80

        for x in 0..<copy.pixelsWide {
            for y in 0..<copy.pixelsHigh {
                guard let color = copy.colorAt(x: x, y: y) else { continue }
                let whiteness = min(color.redComponent, color.greenComponent, color.blueComponent)
                if whiteness >= threshold {
                    copy.setColor(NSColor.clear, atX: x, y: y)
                    continue
                }
                if whiteness > fadeStart {
                    let alphaScale = max(0.12, (threshold - whiteness) / (threshold - fadeStart))
                    let adjusted = NSColor(
                        calibratedRed: color.redComponent,
                        green: color.greenComponent,
                        blue: color.blueComponent,
                        alpha: color.alphaComponent * alphaScale
                    )
                    copy.setColor(adjusted, atX: x, y: y)
                }
            }
        }
        return copy
    }
}
