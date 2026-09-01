import Testing
@testable import PMSetPane

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
