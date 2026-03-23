import SwiftUI

enum AppTab: Hashable {
    case document
    case scan
}

struct ContentView: View {
    @EnvironmentObject private var workspace: DocumentWorkspace
    @State private var selectedTab: AppTab = .document

    var body: some View {
        TabView(selection: $selectedTab) {
            DocumentWorkspaceView()
                .tabItem {
                    Label("문서", systemImage: "doc.richtext")
                }
                .tag(AppTab.document)

            ScanCenterView(selectedTab: $selectedTab)
                .tabItem {
                    Label("스캔", systemImage: "scanner")
                }
                .tag(AppTab.scan)
        }
        .overlay(alignment: .bottomLeading) {
            Text(workspace.statusMessage)
                .font(.callout)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .padding()
        }
    }
}
