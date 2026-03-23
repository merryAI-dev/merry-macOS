import Foundation
@preconcurrency import ImageCaptureCore

final class ScannerCenter: NSObject, ObservableObject, @unchecked Sendable {
    @Published private(set) var devices: [ScannerDeviceRecord] = []
    @Published var selectedDeviceID: String?
    @Published var statusMessage = "스캐너 검색 전"

    private let browser = ICDeviceBrowser()
    private var deviceLookup: [String: ICScannerDevice] = [:]

    override init() {
        super.init()
        browser.delegate = self
        browser.browsedDeviceTypeMask = ICDeviceTypeMask(rawValue:
            ICDeviceTypeMask.scanner.rawValue |
            ICDeviceLocationTypeMask.local.rawValue |
            ICDeviceLocationTypeMask.shared.rawValue |
            ICDeviceLocationTypeMask.bonjour.rawValue
        ) ?? .scanner
    }

    func startDiscovery() {
        devices.removeAll()
        deviceLookup.removeAll()
        selectedDeviceID = nil
        statusMessage = "스캐너 검색 중..."
        browser.start()
    }

    func stopDiscovery() {
        browser.stop()
    }

    func scannerDevice(for id: String?) -> ICScannerDevice? {
        guard let id else { return nil }
        return deviceLookup[id]
    }
}

extension ScannerCenter: ICDeviceBrowserDelegate {
    nonisolated func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
        guard let scanner = device as? ICScannerDevice else { return }
        DispatchQueue.main.async {
            let record = ScannerDeviceRecord(device: scanner)
            self.deviceLookup[record.id] = scanner
            if !self.devices.contains(record) {
                self.devices.append(record)
                self.devices.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
            self.statusMessage = "\(self.devices.count)대의 스캐너 감지"
            if self.selectedDeviceID == nil {
                self.selectedDeviceID = record.id
            }
        }
    }

    nonisolated func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
        guard let scanner = device as? ICScannerDevice else { return }
        let id = scanner.uuidString ?? ""
        DispatchQueue.main.async {
            self.deviceLookup.removeValue(forKey: id)
            self.devices.removeAll { $0.id == id }
            if self.selectedDeviceID == id {
                self.selectedDeviceID = self.devices.first?.id
            }
            self.statusMessage = self.devices.isEmpty ? "감지된 스캐너가 없습니다." : "\(self.devices.count)대의 스캐너 감지"
        }
    }

    nonisolated func deviceBrowserDidEnumerateLocalDevices(_ browser: ICDeviceBrowser) {
        DispatchQueue.main.async {
            if self.devices.isEmpty {
                self.statusMessage = "macOS에서 노출된 스캐너가 아직 없습니다."
            }
        }
    }
}
