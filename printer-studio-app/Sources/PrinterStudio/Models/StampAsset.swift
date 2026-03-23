import AppKit
import Foundation

struct StampAsset: Identifiable, Hashable {
    let id: UUID
    var name: String
    var fileURL: URL
    var imageSize: CGSize
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        fileURL: URL,
        imageSize: CGSize,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.fileURL = fileURL
        self.imageSize = imageSize
        self.createdAt = createdAt
    }
}
