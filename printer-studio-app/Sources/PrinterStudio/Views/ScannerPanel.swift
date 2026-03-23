import AppKit
@preconcurrency import ImageCaptureCore
@preconcurrency import Quartz
import SwiftUI

struct ScannerPanel: NSViewRepresentable {
    let device: ICScannerDevice
    let downloadsDirectory: URL
    let onScanComplete: (URL) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanComplete: onScanComplete, onError: onError)
    }

    func makeNSView(context: Context) -> IKScannerDeviceView {
        let view = IKScannerDeviceView(frame: .zero)
        configure(view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: IKScannerDeviceView, context: Context) {
        configure(nsView, coordinator: context.coordinator)
    }

    private func configure(_ view: IKScannerDeviceView, coordinator: Coordinator) {
        view.delegate = coordinator
        view.mode = IKScannerDeviceViewDisplayMode(rawValue: 2) ?? .advanced
        view.transferMode = IKScannerDeviceViewTransferMode(rawValue: 0) ?? .fileBased
        view.displaysDownloadsDirectoryControl = true
        view.displaysPostProcessApplicationControl = false
        view.downloadsDirectory = downloadsDirectory
        view.documentName = "PrinterStudioScan"
        coordinator.attach(device: device)
        view.scannerDevice = device
    }

    final class Coordinator: NSObject, IKScannerDeviceViewDelegate, ICDeviceDelegate {
        private var activeDevice: ICScannerDevice?
        private let onScanComplete: (URL) -> Void
        private let onError: (String) -> Void

        init(
            onScanComplete: @escaping (URL) -> Void,
            onError: @escaping (String) -> Void
        ) {
            self.onScanComplete = onScanComplete
            self.onError = onError
        }

        func attach(device: ICScannerDevice) {
            guard activeDevice !== device else { return }
            activeDevice?.requestCloseSession()
            activeDevice = device
            device.delegate = self
            device.requestOpenSession()
        }

        func device(_ device: ICDevice, didOpenSessionWithError error: Error?) {
            if let error {
                onError("스캐너 세션 열기 실패: \(error.localizedDescription)")
            }
        }

        func device(_ device: ICDevice, didCloseSessionWithError error: Error?) {
            if let error {
                onError("스캐너 세션 종료 실패: \(error.localizedDescription)")
            }
        }

        func didRemove(_ device: ICDevice) {
            onError("선택한 스캐너 연결이 종료되었습니다.")
        }

        func device(_ device: ICDevice, didReceiveStatusInformation status: [ICDeviceStatus: Any]) {
            if let notice = status[.localizedStatusNotificationKey] as? String {
                onError(notice)
            }
        }

        func scannerDeviceView(_ scannerDeviceView: IKScannerDeviceView, didScanTo url: URL, error: Error?) {
            if let error {
                onError("스캔 실패: \(error.localizedDescription)")
                return
            }
            onScanComplete(url)
        }

        func scannerDeviceView(_ scannerDeviceView: IKScannerDeviceView, didEncounterError error: Error) {
            onError("스캔 오류: \(error.localizedDescription)")
        }
    }
}
