import AppKit
import SwiftUI

struct PDFCanvasView: View {
    @EnvironmentObject private var workspace: DocumentWorkspace
    let pageImage: NSImage

    @State private var dragOrigins: [UUID: StampPlacement] = [:]

    var body: some View {
        GeometryReader { geometry in
            let pageSize = workspace.sizeForPage(at: workspace.selectedPageIndex)
            let pageRect = fittedRect(contentSize: pageImage.size, in: geometry.size)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(red: 0.88, green: 0.90, blue: 0.94))
                    .padding(18)

                RoundedRectangle(cornerRadius: 18)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
                    .frame(width: pageRect.width, height: pageRect.height)
                    .position(x: pageRect.midX, y: pageRect.midY)

                Image(nsImage: pageImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: pageRect.width, height: pageRect.height)
                    .position(x: pageRect.midX, y: pageRect.midY)

                ForEach(workspace.placementsForSelectedPage()) { placement in
                    if let asset = workspace.asset(for: placement.assetID),
                       let stampImage = workspace.image(for: placement.assetID) {
                        let rect = screenRect(
                            for: placement,
                            assetSize: asset.imageSize,
                            pageSize: pageSize,
                            pageRect: pageRect
                        )

                        Image(nsImage: stampImage)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: rect.width, height: rect.height)
                            .rotationEffect(.degrees(placement.rotationDegrees))
                            .opacity(placement.opacity)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        workspace.selectedPlacementID == placement.id ? Color.accentColor : .clear,
                                        style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                                    )
                            }
                            .position(x: rect.midX, y: rect.midY)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                workspace.selectPlacement(placement.id)
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        if dragOrigins[placement.id] == nil {
                                            dragOrigins[placement.id] = placement
                                        }
                                        workspace.selectPlacement(placement.id)
                                        workspace.movePlacement(
                                            placement.id,
                                            from: dragOrigins[placement.id] ?? placement,
                                            translation: value.translation,
                                            canvasSize: pageRect.size
                                        )
                                    }
                                    .onEnded { _ in
                                        dragOrigins[placement.id] = nil
                                    }
                            )
                    }
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.8), value: workspace.placements)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func fittedRect(contentSize: CGSize, in containerSize: CGSize) -> CGRect {
        let safeContentWidth = max(contentSize.width, 1)
        let safeContentHeight = max(contentSize.height, 1)
        let scale = min(containerSize.width / safeContentWidth, containerSize.height / safeContentHeight)
        let width = safeContentWidth * scale * 0.92
        let height = safeContentHeight * scale * 0.92
        let originX = (containerSize.width - width) / 2
        let originY = (containerSize.height - height) / 2
        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    private func screenRect(
        for placement: StampPlacement,
        assetSize: CGSize,
        pageSize: CGSize,
        pageRect: CGRect
    ) -> CGRect {
        let normalizedRect = placement.normalizedRect(assetSize: assetSize, pageSize: pageSize)
        let width = normalizedRect.width * pageRect.width
        let height = normalizedRect.height * pageRect.height
        let x = pageRect.minX + (normalizedRect.minX * pageRect.width)
        let y = pageRect.maxY - ((normalizedRect.minY + normalizedRect.height) * pageRect.height)

        return CGRect(x: x, y: y, width: width, height: height)
    }
}
