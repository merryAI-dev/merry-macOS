import Foundation
@preconcurrency import ImageCaptureCore

struct ScannerDeviceRecord: Identifiable, Equatable {
    let id: String
    let name: String
    let productKind: String
    let transportType: String
    let locationDescription: String

    init(device: ICScannerDevice) {
        self.id = device.uuidString ?? UUID().uuidString
        self.name = device.name ?? "이름 없는 스캐너"
        self.productKind = device.productKind ?? "Scanner"
        self.transportType = device.transportType ?? "Unknown"
        self.locationDescription = device.locationDescription ?? "네트워크"
    }
}
