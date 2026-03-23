import Foundation
import ImageCaptureCore

final class ScannerBrowser: NSObject, ICDeviceBrowserDelegate {
    private let browser = ICDeviceBrowser()
    private var discovered = false

    func run(timeout: TimeInterval = 6.0) {
        browser.delegate = self
        browser.browsedDeviceTypeMask = ICDeviceTypeMask(rawValue: ICDeviceTypeMask.scanner.rawValue | ICDeviceLocationTypeMask.local.rawValue | ICDeviceLocationTypeMask.shared.rawValue | ICDeviceLocationTypeMask.bonjour.rawValue)
        browser.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            self.browser.stop()
            if !self.discovered {
                print("No scanners discovered.")
            }
            CFRunLoopStop(CFRunLoopGetMain())
        }
        RunLoop.main.run()
    }

    func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
        discovered = true
        let payload: [String: Any?] = [
            "name": device.name,
            "productKind": device.productKind,
            "transportType": device.transportType,
            "locationDescription": device.locationDescription,
            "uuid": device.UUIDString,
            "modulePath": device.modulePath,
            "moduleVersion": device.moduleVersion,
            "type": device.type.rawValue,
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload.compactMapValues { $0 }, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    }

    func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
    }

    func deviceBrowserDidEnumerateLocalDevices(_ browser: ICDeviceBrowser) {
        if !discovered {
            print("Local scan devices enumeration finished.")
        }
    }
}

ScannerBrowser().run()
