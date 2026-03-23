import SwiftUI

@main
struct PrinterLauncherApp: App {
    @StateObject private var workspace = PrintWorkspace()
    @StateObject private var setup = SetupService(
        harnessURL: PrintService.defaultHarnessURL(),
        queueName: "_6l85k35m5_j80"
    )
    @State private var showSetup = false

    var body: some Scene {
        WindowGroup("Print Launcher") {
            PrintWorkspaceView()
                .environmentObject(workspace)
                .environmentObject(setup)
                .frame(minWidth: 1080, minHeight: 760)
                .task {
                    await setup.checkAll()
                    if !setup.allReady {
                        showSetup = true
                    }
                }
                .sheet(isPresented: $showSetup) {
                    SetupView()
                        .environmentObject(setup)
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1220, height: 820)
    }
}
