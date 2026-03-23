import SwiftUI

struct SetupView: View {
    @EnvironmentObject private var setup: SetupService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            items
            if let err = setup.fixError { errorRow(err) }
            actions
        }
        .frame(width: 480)
        .background(.background)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "printer.fill.and.paper.fill")
                .font(.system(size: 24))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text("인쇄 앱 설정")
                    .font(.headline)
                Text(setup.allReady
                     ? "모든 항목이 준비됐어요."
                     : "아래 항목을 확인하고 자동으로 설정해요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }

    // MARK: - Items

    private var items: some View {
        VStack(spacing: 0) {
            Divider()
            ForEach(setup.items) { item in
                ItemRow(item: item)
                Divider().padding(.leading, 56)
            }
            Divider()
        }
    }

    // MARK: - Error

    private func errorRow(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    // MARK: - Actions

    private var actions: some View {
        HStack {
            Button("나중에") { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.subheadline)
                .disabled(setup.isRunning)

            Spacer()

            if setup.allReady {
                Button("완료") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
            } else if setup.hasPendingFixes {
                Button {
                    Task { await setup.runFixes() }
                } label: {
                    if setup.isRunning {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("설정 중…")
                        }
                    } else {
                        Text("자동 설정")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(setup.isRunning)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// MARK: - Item Row

private struct ItemRow: View {
    let item: SetupItem

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            statusIcon
                .frame(width: 32, height: 32)

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                if let sub = subtitle {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Badge
            badge
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .animation(.easeInOut(duration: 0.2), value: item.status)
    }

    // MARK: Status Icon

    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .pending:
            Image(systemName: iconName)
                .font(.system(size: 15))
                .foregroundStyle(.tertiary)
        case .checking:
            ProgressView()
                .controlSize(.small)
        case .ok:
            Image(systemName: iconName)
                .font(.system(size: 15))
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: iconName)
                .font(.system(size: 15))
                .foregroundStyle(item.fixable ? .orange : .red)
        }
    }

    // MARK: Badge

    @ViewBuilder
    private var badge: some View {
        switch item.status {
        case .pending:
            EmptyView()
        case .checking:
            EmptyView()
        case .ok:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Text(item.fixable ? "자동 수정 가능" : "직접 설치 필요")
                .font(.caption.weight(.medium))
                .foregroundStyle(item.fixable ? .orange : .red)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(item.fixable
                              ? Color.orange.opacity(0.1)
                              : Color.red.opacity(0.1))
                )
        }
    }

    // MARK: Helpers

    private var iconName: String {
        switch item.id {
        case "python": return "terminal"
        case "driver": return "printer"
        case "queue":  return "tray.2"
        case "ppd":    return "gearshape"
        default:       return "gear"
        }
    }

    private var subtitle: String? {
        switch item.status {
        case .ok, .pending: return nil
        case .checking:     return "확인 중…"
        case .failed:       return item.subtitle
        }
    }
}
