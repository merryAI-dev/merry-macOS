import Foundation

enum PrintServiceError: LocalizedError {
    case harnessMissing(URL)
    case printFailed(String)

    var errorDescription: String? {
        switch self {
        case .harnessMissing(let url):
            "인쇄 하네스를 찾지 못했습니다: \(url.path)"
        case .printFailed(let message):
            message.isEmpty ? "인쇄 요청에 실패했습니다." : message
        }
    }
}

struct PrintService: Sendable {
    let harnessURL: URL
    let queueName: String
    let presetSource: String

    init(
        harnessURL: URL = URL(fileURLWithPath: "/Users/boram/printer-harness/printer_harness.py"),
        queueName: String = "_6l85k35m5_j80",
        presetSource: String = "global-vendor-default"
    ) {
        self.harnessURL = harnessURL
        self.queueName = queueName
        self.presetSource = presetSource
    }

    func printFile(_ fileURL: URL, preset: PrintPreset) throws -> String {
        guard FileManager.default.fileExists(atPath: harnessURL.path) else {
            throw PrintServiceError.harnessMissing(harnessURL)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")

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

        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

        guard process.terminationStatus == 0 else {
            throw PrintServiceError.printFailed(text)
        }
        return text
    }
}
