import Foundation

enum ScreenSaverAutomationAgentError: LocalizedError {
    case monitorMissing
    case launchctlFailed(String)

    var errorDescription: String? {
        switch self {
        case .monitorMissing: "The screen saver monitor is missing from this preference pane."
        case let .launchctlFailed(message): message
        }
    }
}

final class ScreenSaverAutomationAgent {
    private static let label = "io.github.generald.power-management.monitor"

    func setEnabled(_ enabled: Bool, monitorURL: URL) throws {
        let agentURL = launchAgentURL
        try stop(agentURL: agentURL)

        guard enabled else {
            try? FileManager.default.removeItem(at: agentURL)
            return
        }

        guard FileManager.default.isExecutableFile(atPath: monitorURL.path) else {
            throw ScreenSaverAutomationAgentError.monitorMissing
        }

        try FileManager.default.createDirectory(at: agentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let propertyList: [String: Any] = [
            "Label": Self.label,
            "ProgramArguments": [monitorURL.path],
            "RunAtLoad": true,
            "KeepAlive": ["SuccessfulExit": false],
            "ProcessType": "Background",
            "ThrottleInterval": 10,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: propertyList, format: .xml, options: 0)
        try data.write(to: agentURL, options: .atomic)
        try launchctl(arguments: ["bootstrap", "gui/\(getuid())", agentURL.path])
    }

    private var launchAgentURL: URL {
        FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appending(path: "LaunchAgents")
            .appending(path: "io.github.generald.power-management.monitor.plist")
    }

    private func stop(agentURL: URL) throws {
        guard FileManager.default.fileExists(atPath: agentURL.path) else { return }
        try? launchctl(arguments: ["bootout", "gui/\(getuid())", agentURL.path])
    }

    private func launchctl(arguments: [String]) throws {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw ScreenSaverAutomationAgentError.launchctlFailed(output.isEmpty ? "Could not update the screen saver monitor." : output)
        }
    }
}
