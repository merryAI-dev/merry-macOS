import SwiftUI

@main
struct PrinterStudioApp: App {
    @StateObject private var workspace = DocumentWorkspace()
    @StateObject private var scannerCenter = ScannerCenter()

    var body: some Scene {
        WindowGroup("Printer Studio") {
            ContentView()
                .environmentObject(workspace)
                .environmentObject(scannerCenter)
                .frame(minWidth: 1320, minHeight: 860)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1460, height: 920)
    }
}
