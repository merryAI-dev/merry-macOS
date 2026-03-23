import Foundation

enum PrintServiceError: LocalizedError {
    case harnessMissing(URL)
    case fileMissing(URL)
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .harnessMissing(let url):
            "인쇄 하네스를 찾지 못했습니다: \(url.path)"
        case .fileMissing(let url):
            "인쇄할 PDF를 찾지 못했습니다: \(url.path)"
        case .processFailed(let message):
            message.isEmpty ? "인쇄 작업에 실패했습니다." : message
        }
    }
}

struct PrintService: Sendable {
    let harnessURL: URL
    let queueName: String
    let presetSource: String

    init(
        harnessURL: URL = Self.defaultHarnessURL(),
        queueName: String = "_6l85k35m5_j80",
        presetSource: String = "global-vendor-default"
    ) {
        self.harnessURL = harnessURL
        self.queueName = queueName
        self.presetSource = presetSource
    }

    private static func defaultHarnessURL() -> URL {
        // 앱 번들 안의 리소스 우선 탐색
        if let bundled = Bundle.main.url(forResource: "printer_harness", withExtension: "py") {
            return bundled
        }
        // 개발 환경 fallback
        return URL(fileURLWithPath: "/Users/boram/printer-harness/printer_harness.py")
    }

    func printFile(_ fileURL: URL, preset: PrintPreset) throws -> String {
        guard FileManager.default.fileExists(atPath: harnessURL.path) else {
            throw PrintServiceError.harnessMissing(harnessURL)
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw PrintServiceError.fileMissing(fileURL)
        }

        return try runHarness(arguments: buildPrintArguments(fileURL: fileURL, preset: preset))
    }

    func queueStatus() throws -> String {
        guard FileManager.default.fileExists(atPath: harnessURL.path) else {
            throw PrintServiceError.harnessMissing(harnessURL)
        }
        return try runHarness(arguments: [
            harnessURL.path,
            "status",
            "--queue-name",
            queueName,
        ])
    }

    private func buildPrintArguments(fileURL: URL, preset: PrintPreset) -> [String] {
        var arguments = [
            harnessURL.path,
            "print",
            fileURL.path,
            "--queue-name",
            queueName,
            "--preset-source",
            presetSource,
            "--duplex",
            preset.duplexMode,
        ]

        for (key, value) in preset.optionPairs {
            arguments.append(contentsOf: ["--option", "\(key)=\(value)"])
        }
        return arguments
    }

    private func runHarness(arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

        guard process.terminationStatus == 0 else {
            throw PrintServiceError.processFailed(text)
        }
        return text
    }
}
