import Foundation

public enum PowerSource: CaseIterable, Sendable {
    case battery
    case ac

    var label: String {
        switch self {
        case .battery: "Battery"
        case .ac: "Power Adapter"
        }
    }

    var pmsetArgument: String {
        switch self {
        case .battery: "-b"
        case .ac: "-c"
        }
    }

    var sectionHeader: String {
        switch self {
        case .battery: "Battery Power:"
        case .ac: "AC Power:"
        }
    }
}

public struct PowerSettings: Equatable, Sendable {
    public var displaySleep: Int
    public var systemSleep: Int
    public var diskSleep: Int
    public var wakeForNetwork: Bool

    public init(displaySleep: Int, systemSleep: Int, diskSleep: Int, wakeForNetwork: Bool) {
        self.displaySleep = displaySleep
        self.systemSleep = systemSleep
        self.diskSleep = diskSleep
        self.wakeForNetwork = wakeForNetwork
    }

    var isValid: Bool {
        systemSleep == 0 || (displaySleep > 0 && displaySleep <= systemSleep)
    }
}

public enum PMSetOutput {
    public static func settings(in output: String, source: PowerSource) -> PowerSettings? {
        let section = output
            .components(separatedBy: source.sectionHeader)
            .dropFirst()
            .first?
            .components(separatedBy: "Power:")
            .first

        guard let section else { return nil }

        let values = Dictionary(
            uniqueKeysWithValues: section
                .split(whereSeparator: \.isNewline)
                .compactMap { line -> (String, Int)? in
                    let fields = line.split(whereSeparator: \.isWhitespace)
                    guard fields.count >= 2, let value = Int(fields[1]) else { return nil }
                    return (String(fields[0]), value)
                }
        )

        guard
            let displaySleep = values["displaysleep"],
            let systemSleep = values["sleep"],
            let diskSleep = values["disksleep"],
            let wakeForNetwork = values["womp"]
        else { return nil }

        return PowerSettings(
            displaySleep: displaySleep,
            systemSleep: systemSleep,
            diskSleep: diskSleep,
            wakeForNetwork: wakeForNetwork != 0
        )
    }
}
