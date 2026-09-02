import Foundation
import IOKit.ps

public enum ActivePowerSource: Sendable {
    case battery
    case powerAdapter
}

public struct ScreenSaverAutomationConfiguration: Equatable, Sendable {
    public var isEnabled: Bool
    public var batteryMinutes: Int
    public var powerAdapterMinutes: Int

    public init(isEnabled: Bool, batteryMinutes: Int, powerAdapterMinutes: Int) {
        self.isEnabled = isEnabled
        self.batteryMinutes = batteryMinutes
        self.powerAdapterMinutes = powerAdapterMinutes
    }

    public func minutes(for source: ActivePowerSource) -> Int {
        switch source {
        case .battery: batteryMinutes
        case .powerAdapter: powerAdapterMinutes
        }
    }
}

public enum ScreenSaverAutomation {
    private static let defaults = UserDefaults(suiteName: "io.github.generald.power-management")!
    private static let enabledKey = "screenSaverAutomationEnabled"
    private static let batteryKey = "screenSaverBatteryMinutes"
    private static let powerAdapterKey = "screenSaverPowerAdapterMinutes"

    public static var configuration: ScreenSaverAutomationConfiguration {
        ScreenSaverAutomationConfiguration(
            isEnabled: defaults.bool(forKey: enabledKey),
            batteryMinutes: storedMinutes(forKey: batteryKey, fallback: 5),
            powerAdapterMinutes: storedMinutes(forKey: powerAdapterKey, fallback: 10)
        )
    }

    public static func save(_ configuration: ScreenSaverAutomationConfiguration) {
        defaults.set(configuration.isEnabled, forKey: enabledKey)
        defaults.set(configuration.batteryMinutes, forKey: batteryKey)
        defaults.set(configuration.powerAdapterMinutes, forKey: powerAdapterKey)
    }

    public static func applyCurrentPowerSource() throws {
        let configuration = configuration
        guard configuration.isEnabled else { return }
        try setScreenSaverIdleTime(configuration.minutes(for: currentPowerSource()))
    }

    public static func currentPowerSource() -> ActivePowerSource {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let type = IOPSGetProvidingPowerSourceType(snapshot).takeUnretainedValue() as String
        return type == kIOPSACPowerValue ? .powerAdapter : .battery
    }

    private static func setScreenSaverIdleTime(_ minutes: Int) throws {
        let seconds = max(0, minutes) * 60
        CFPreferencesSetValue(
            "idleTime" as CFString,
            seconds as CFPropertyList,
            "com.apple.screensaver" as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )
        guard CFPreferencesSynchronize(
            "com.apple.screensaver" as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        ) else {
            throw ScreenSaverAutomationError.preferencesNotSaved
        }
    }

    private static func storedMinutes(forKey key: String, fallback: Int) -> Int {
        let value = defaults.object(forKey: key) as? Int ?? fallback
        return value >= 0 ? value : fallback
    }
}

public enum ScreenSaverAutomationError: LocalizedError {
    case preferencesNotSaved

    public var errorDescription: String? {
        "Could not save the screen saver setting."
    }
}
