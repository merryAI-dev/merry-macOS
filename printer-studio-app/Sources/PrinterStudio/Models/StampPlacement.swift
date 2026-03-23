import CoreGraphics
import Foundation

struct StampPlacement: Identifiable, Equatable {
    let id: UUID
    let assetID: UUID
    var pageIndex: Int
    var centerX: CGFloat
    var centerY: CGFloat
    var normalizedWidth: CGFloat
    var rotationDegrees: CGFloat
    var opacity: Double

    init(
        id: UUID = UUID(),
        assetID: UUID,
        pageIndex: Int,
        centerX: CGFloat = 0.5,
        centerY: CGFloat = 0.5,
        normalizedWidth: CGFloat = 0.25,
        rotationDegrees: CGFloat = 0,
        opacity: Double = 1
    ) {
        self.id = id
        self.assetID = assetID
        self.pageIndex = pageIndex
        self.centerX = centerX
        self.centerY = centerY
        self.normalizedWidth = normalizedWidth
        self.rotationDegrees = rotationDegrees
        self.opacity = opacity
    }

    func normalizedRect(assetSize: CGSize, pageSize: CGSize) -> CGRect {
        let safePageWidth = max(pageSize.width, 1)
        let safePageHeight = max(pageSize.height, 1)
        let safeAssetWidth = max(assetSize.width, 1)
        let safeAssetHeight = max(assetSize.height, 1)

        let width = min(max(normalizedWidth, 0.05), 0.95)
        let height = min(
            max(width * (safeAssetHeight / safeAssetWidth) * (safePageWidth / safePageHeight), 0.03),
            0.95
        )

        let halfWidth = width / 2
        let halfHeight = height / 2
        let clampedCenterX = min(max(centerX, halfWidth), 1 - halfWidth)
        let clampedCenterY = min(max(centerY, halfHeight), 1 - halfHeight)

        return CGRect(
            x: clampedCenterX - halfWidth,
            y: clampedCenterY - halfHeight,
            width: width,
            height: height
        )
    }

    func clamped(assetSize: CGSize, pageSize: CGSize) -> StampPlacement {
        let rect = normalizedRect(assetSize: assetSize, pageSize: pageSize)
        var copy = self
        copy.centerX = rect.midX
        copy.centerY = rect.midY
        copy.normalizedWidth = rect.width
        return copy
    }
}
