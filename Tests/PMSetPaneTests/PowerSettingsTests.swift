import Testing
@testable import PMSetPane
@testable import PowerManagementCore

@Test func parsedACSettings() throws {
    let output = """
    Battery Power:
     displaysleep 10
     sleep 0
     disksleep 10
     womp 0
    AC Power:
     displaysleep 30
     sleep 0
     disksleep 10
     womp 1
    """

    #expect(PMSetOutput.settings(in: output, source: .ac) == PowerSettings(displaySleep: 30, systemSleep: 0, diskSleep: 10, wakeForNetwork: true))
}

@Test func missingRequiredSettingFailsToParse() {
    #expect(PMSetOutput.settings(in: "AC Power:\n displaysleep 30", source: .ac) == nil)
}

@Test func privilegedScriptUsesValidAppleScriptQuotes() {
    #expect(
        PMSetClient.privilegedScript(command: "/usr/bin/pmset -c sleep 0")
            == "do shell script \"/usr/bin/pmset -c sleep 0\" with administrator privileges"
    )
}

@Test func screenSaverUsesTheConfiguredPowerSourceTimeout() {
    let configuration = ScreenSaverAutomationConfiguration(
        isEnabled: true,
        batteryMinutes: 1,
        powerAdapterMinutes: 10
    )

    #expect(configuration.minutes(for: .battery) == 1)
    #expect(configuration.minutes(for: .powerAdapter) == 10)
}

@Test func screenSaverPushesLaterTimersForward() {
    let timeline = TimerTimeline(screenSaver: 30, displaySleep: 20, systemSleep: 25)
        .adjusted(for: .screenSaver)

    #expect(timeline == TimerTimeline(screenSaver: 30, displaySleep: 31, systemSleep: 31))
}

@Test func earlierSystemSleepPushesTimersBackward() {
    let timeline = TimerTimeline(screenSaver: 20, displaySleep: 30, systemSleep: 15)
        .adjusted(for: .systemSleep)

    #expect(timeline == TimerTimeline(screenSaver: 14, displaySleep: 15, systemSleep: 15))
}

@Test func systemSleepCanRemainNever() {
    let timeline = TimerTimeline(screenSaver: 20, displaySleep: 30, systemSleep: TimerTimeline.never)
        .adjusted(for: .systemSleep)

    #expect(TimerTimeline.minutes(for: timeline.systemSleep) == 0)
}
