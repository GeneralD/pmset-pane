import Foundation

enum PMSetError: LocalizedError {
    case unavailable
    case invalidTimers
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable: "Could not read the current power settings."
        case .invalidTimers: "Display sleep must occur before system sleep, unless system sleep is set to Never."
        case let .commandFailed(message): message
        }
    }
}

final class PMSetClient {
    func currentSettings() throws -> [PowerSource: PowerSettings] {
        let output = try output(arguments: ["-g", "custom"])
        return Dictionary(uniqueKeysWithValues: PowerSource.allCases.compactMap { source in
            PMSetOutput.settings(in: output, source: source).map { (source, $0) }
        })
    }

    func apply(_ settings: PowerSettings, to source: PowerSource) throws {
        guard settings.isValid else { throw PMSetError.invalidTimers }

        let command = [
            "/usr/bin/pmset", source.pmsetArgument,
            "displaysleep", String(settings.displaySleep),
            "sleep", String(settings.systemSleep),
            "disksleep", String(settings.diskSleep),
            "womp", settings.wakeForNetwork ? "1" : "0",
        ].joined(separator: " ")
        _ = try output(arguments: ["-e", Self.privilegedScript(command: command)], executable: "/usr/bin/osascript")
    }

    static func privilegedScript(command: String) -> String {
        "do shell script \"\(command)\" with administrator privileges"
    }

    private func output(arguments: [String], executable: String = "/usr/bin/pmset") throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            throw PMSetError.unavailable
        }
        process.waitUntilExit()

        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw PMSetError.commandFailed(output.isEmpty ? "The power-management command failed." : output)
        }
        return output
    }
}
