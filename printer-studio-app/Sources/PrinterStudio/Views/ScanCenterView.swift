import SwiftUI

struct ScanCenterView: View {
    @EnvironmentObject private var workspace: DocumentWorkspace
    @EnvironmentObject private var scannerCenter: ScannerCenter

    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            scannerSidebar
            Divider()
            scannerPanel
        }
        .onAppear {
            scannerCenter.startDiscovery()
        }
        .onDisappear {
            scannerCenter.stopDiscovery()
        }
    }

    private var scannerSidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("스캐너")
                        .font(.title2.bold())
                    Text(scannerCenter.statusMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    scannerCenter.startDiscovery()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }

            if scannerCenter.devices.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("아직 macOS에 노출된 스캐너가 없습니다.")
                    Text("캐논 장비가 Image Capture 쪽으로 잡히면 우측에 기본 스캔 패널이 뜹니다.")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(scannerCenter.devices) { device in
                            Button {
                                scannerCenter.selectedDeviceID = device.id
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(device.name)
                                        .font(.headline)
                                    Text(device.productKind)
                                        .font(.callout)
                                    Text("\(device.transportType) · \(device.locationDescription)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(scannerCenter.selectedDeviceID == device.id ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.7))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 330)
        .background(
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.98, blue: 0.99), Color(red: 0.95, green: 0.96, blue: 0.94)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    @ViewBuilder
    private var scannerPanel: some View {
        if let selectedDevice = scannerCenter.scannerDevice(for: scannerCenter.selectedDeviceID) {
            ScannerPanel(
                device: selectedDevice,
                downloadsDirectory: AppPaths.scanDirectory,
                onScanComplete: { url in
                    do {
                        try workspace.openDocument(at: url)
                        selectedTab = .document
                    } catch {
                        workspace.statusMessage = error.localizedDescription
                    }
                },
                onError: { message in
                    workspace.statusMessage = message
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 14) {
                Image(systemName: "scanner.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(.secondary)
                Text("왼쪽에서 스캐너를 선택하면 macOS 기본 스캔 UI를 이 안에 띄웁니다.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 360)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.95, green: 0.95, blue: 0.97))
        }
    }
}
