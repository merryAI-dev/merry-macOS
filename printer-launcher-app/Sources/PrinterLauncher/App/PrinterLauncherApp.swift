import SwiftUI

@main
struct PrinterLauncherApp: App {
    @StateObject private var workspace = PrintWorkspace()

    var body: some Scene {
        WindowGroup("Print Launcher") {
            PrintWorkspaceView()
                .environmentObject(workspace)
                .frame(minWidth: 1080, minHeight: 760)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1220, height: 820)
    }
}
