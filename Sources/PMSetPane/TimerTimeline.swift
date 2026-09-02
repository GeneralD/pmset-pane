import Foundation

enum TimerTimelinePosition {
    case screenSaver
    case displaySleep
    case systemSleep
}

struct TimerTimeline: Equatable {
    static let never = 121

    var screenSaver: Int
    var displaySleep: Int
    var systemSleep: Int

    init(screenSaver: Int, displaySleep: Int, systemSleep: Int) {
        self.screenSaver = screenSaver
        self.displaySleep = displaySleep
        self.systemSleep = systemSleep
    }

    init(screenSaverMinutes: Int, displaySleepMinutes: Int, systemSleepMinutes: Int) {
        self.init(
            screenSaver: Self.sliderValue(for: screenSaverMinutes),
            displaySleep: Self.sliderValue(for: displaySleepMinutes),
            systemSleep: Self.sliderValue(for: systemSleepMinutes)
        )
    }

    static func sliderValue(for minutes: Int) -> Int {
        minutes == 0 ? never : min(max(minutes, 1), never - 1)
    }

    static func minutes(for sliderValue: Int) -> Int {
        sliderValue >= never ? 0 : max(sliderValue, 1)
    }

    func adjusted(for changed: TimerTimelinePosition) -> Self {
        switch changed {
        case .screenSaver:
            let screenSaver = min(max(screenSaver, 1), Self.never - 1)
            let displaySleep = max(min(max(displaySleep, 2), Self.never), screenSaver + 1)
            return Self(
                screenSaver: screenSaver,
                displaySleep: displaySleep,
                systemSleep: max(min(max(systemSleep, 2), Self.never), displaySleep)
            )
        case .displaySleep:
            let displaySleep = max(min(max(displaySleep, 2), Self.never), 2)
            return Self(
                screenSaver: min(max(screenSaver, 1), displaySleep - 1),
                displaySleep: displaySleep,
                systemSleep: max(min(max(systemSleep, 2), Self.never), displaySleep)
            )
        case .systemSleep:
            let systemSleep = max(min(max(systemSleep, 2), Self.never), 2)
            let displaySleep = min(max(displaySleep, 2), systemSleep)
            return Self(
                screenSaver: min(max(screenSaver, 1), displaySleep - 1),
                displaySleep: displaySleep,
                systemSleep: systemSleep
            )
        }
    }
}
