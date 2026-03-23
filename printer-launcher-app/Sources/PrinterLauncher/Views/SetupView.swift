import SwiftUI

struct SetupView: View {
    @EnvironmentObject private var setup: SetupService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            itemList
            Divider()
            footer
        }
        .frame(width: 500)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("초기 설정")
                .font(.title2.weight(.semibold))
            Text("아래 항목을 확인하고, 자동으로 설정할 수 있는 항목은 버튼 한 번으로 완료합니다.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }

    private var itemList: some View {
        VStack(spacing: 0) {
            ForEach(Array(setup.items.enumerated()), id: \.element.id) { index, item in
                SetupItemRow(item: item)
                if index < setup.items.count - 1 {
                    Divider().padding(.leading, 58)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if let error = setup.fixError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer()
            }

            Button("나중에") { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(setup.isRunning)

            if setup.allReady {
                Button("완료") { dismiss() }
                    .buttonStyle(.borderedProminent)
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
                .disabled(setup.isRunning)
            }
        }
        .padding(20)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct SetupItemRow: View {
    let item: SetupItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            statusIcon
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.headline)
                Text(item.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if item.fixable && item.status == .failed {
                Text("자동 수정 가능")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.orange.opacity(0.12), in: Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .pending:
            Image(systemName: "circle")
                .font(.title2)
                .foregroundStyle(.tertiary)
        case .checking:
            ProgressView()
                .controlSize(.small)
        case .ok:
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(item.fixable ? Color.orange : Color.red)
        }
    }
}
