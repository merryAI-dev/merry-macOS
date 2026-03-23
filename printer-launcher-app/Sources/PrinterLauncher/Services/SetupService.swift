import Foundation

enum SetupStatus: Equatable {
    case pending, checking, ok, failed
}

struct SetupItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    var status: SetupStatus = .pending
    let fixable: Bool
}

@MainActor
final class SetupService: ObservableObject {
    @Published private(set) var items: [SetupItem]
    @Published private(set) var isRunning = false
    @Published private(set) var fixError: String?

    let harnessURL: URL
    let queueName: String

    init(harnessURL: URL, queueName: String) {
        self.harnessURL = harnessURL
        self.queueName = queueName
        self.items = [
            SetupItem(
                id: "python",
                title: "Python 3",
                subtitle: "인쇄 하네스 실행에 필요합니다. (/usr/bin/python3)",
                fixable: false
            ),
            SetupItem(
                id: "driver",
                title: "Canon iR-ADV 드라이버",
                subtitle: "Canon 공식 사이트에서 iR-ADV CUPS 드라이버를 설치해주세요.",
                fixable: false
            ),
            SetupItem(
                id: "queue",
                title: "프린터 큐 등록",
                subtitle: "복합기 CUPS 큐를 자동으로 등록합니다. (관리자 비밀번호 필요)",
                fixable: true
            ),
            SetupItem(
                id: "ppd",
                title: "양면 인쇄 허용",
                subtitle: "PPD 파일의 양면 인쇄 옵션을 켭니다. (관리자 비밀번호 필요)",
                fixable: true
            ),
        ]
    }

    var allReady: Bool { items.allSatisfy { $0.status == .ok } }
    var hasPendingFixes: Bool { items.contains { $0.status == .failed && $0.fixable } }

    // MARK: - Check

    func checkAll() async {
        isRunning = true
        fixError = nil
        for i in items.indices { items[i].status = .checking }

        await Task.yield()
        let hasPython = FileManager.default.fileExists(atPath: "/usr/bin/python3")
        setStatus("python", hasPython ? .ok : .failed)

        await Task.yield()
        let hasDriver = FileManager.default.fileExists(
            atPath: "/Library/Printers/Canon/CUPS_Printer/Bins/capdftopdl"
        )
        setStatus("driver", hasDriver ? .ok : .failed)

        let queueName = self.queueName
        let hasQueue = await Task.detached(priority: .userInitiated) {
            (try? Self.runSync("/usr/bin/lpstat", ["-p", queueName])) != nil
        }.value
        setStatus("queue", hasQueue ? .ok : .failed)

        let ppdPath = "/private/etc/cups/ppd/\(queueName).ppd"
        if hasQueue {
            let ppdOk = await Task.detached(priority: .userInitiated) {
                (try? String(contentsOfFile: ppdPath, encoding: .utf8))?
                    .contains("*CNNotChangeDuplex: False") == true
            }.value
            setStatus("ppd", ppdOk ? .ok : .failed)
        } else {
            setStatus("ppd", .pending)
        }

        isRunning = false
    }

    // MARK: - Fix

    func runFixes() async {
        isRunning = true
        fixError = nil

        let harnessPath = harnessURL.path
        let queueName = self.queueName
        let ppdPath = "/private/etc/cups/ppd/\(queueName).ppd"

        var lines = ["#!/bin/bash"]
        if itemStatus("queue") == .failed {
            lines.append(
                "python3 '\(harnessPath)' install"
                    + " --printer-uri ipp://10.10.6.100/ipp/print"
                    + " --location 6층복합기"
            )
        }
        lines.append(
            "if [ -f '\(ppdPath)' ]; then"
                + " sed -i '' 's/*CNNotChangeDuplex: True/*CNNotChangeDuplex: False/' '\(ppdPath)';"
                + " fi"
        )

        let script = lines.joined(separator: "\n")
        let tmpPath = "/tmp/printer_setup_\(Int(Date().timeIntervalSince1970)).sh"

        guard (try? script.write(toFile: tmpPath, atomically: true, encoding: .utf8)) != nil else {
            fixError = "임시 파일 생성에 실패했습니다."
            isRunning = false
            return
        }

        let appleScript = "do shell script \"bash \(tmpPath)\" with administrator privileges"
        let exitCode = await Task.detached(priority: .userInitiated) { () -> Int32 in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", appleScript]
            try? process.run()
            process.waitUntilExit()
            return process.terminationStatus
        }.value

        try? FileManager.default.removeItem(atPath: tmpPath)

        if exitCode != 0 {
            fixError = "설정에 실패했습니다. 비밀번호를 취소했거나 오류가 발생했을 수 있어요."
        }

        // Re-check queue and ppd after fix attempt
        let hasQueue = await Task.detached(priority: .userInitiated) {
            (try? Self.runSync("/usr/bin/lpstat", ["-p", queueName])) != nil
        }.value
        setStatus("queue", hasQueue ? .ok : .failed)

        if hasQueue {
            let ppdOk = await Task.detached(priority: .userInitiated) {
                (try? String(contentsOfFile: ppdPath, encoding: .utf8))?
                    .contains("*CNNotChangeDuplex: False") == true
            }.value
            setStatus("ppd", ppdOk ? .ok : .failed)
        } else {
            setStatus("ppd", .pending)
        }

        isRunning = false
    }

    // MARK: - Helpers

    private nonisolated static func runSync(_ path: String, _ args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "SetupService", code: Int(process.terminationStatus))
        }
        return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    }

    private func setStatus(_ id: String, _ status: SetupStatus) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].status = status
    }

    private func itemStatus(_ id: String) -> SetupStatus {
        items.first { $0.id == id }?.status ?? .pending
    }
}
