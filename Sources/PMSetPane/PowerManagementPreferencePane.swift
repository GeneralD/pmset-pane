@preconcurrency import AppKit
@preconcurrency import PreferencePanes
import PowerManagementCore

@objc(PowerManagementPreferencePane)
public final class PowerManagementPreferencePane: NSPreferencePane {
    private var controller: PowerSettingsViewController?

    public override func loadMainView() -> NSView {
        let pane = self
        return MainActor.assumeIsolated {
            let controller = PowerSettingsViewController()
            pane.controller = controller
            pane.mainView = controller.view
            return pane.mainView
        }
    }
}

private final class PowerSettingsViewController: NSViewController {
    private let client = PMSetClient()
    private var settings = [PowerSource: PowerSettings]()
    private var source = PowerSource.ac

    private let sourceControl = NSSegmentedControl(labels: PowerSource.allCases.map(\.label), trackingMode: .selectOne, target: nil, action: nil)
    private let screenSaverSlider = NSSlider()
    private let displaySleepSlider = NSSlider()
    private let systemSleepSlider = NSSlider()
    private let diskSleepSlider = NSSlider()
    private let screenSaverValue = NSTextField(labelWithString: "")
    private let displaySleepValue = NSTextField(labelWithString: "")
    private let systemSleepValue = NSTextField(labelWithString: "")
    private let diskSleepValue = NSTextField(labelWithString: "")
    private let wakeForNetwork = NSButton(checkboxWithTitle: "Wake for network access", target: nil, action: nil)
    private let status = NSTextField(labelWithString: "")
    private let automationAgent = ScreenSaverAutomationAgent()

    override func loadView() {
        sourceControl.target = self
        sourceControl.action = #selector(sourceChanged)
        sourceControl.selectedSegment = 1
        configure(screenSaverSlider, tag: 0, maximum: TimerTimeline.never - 1)
        configure(displaySleepSlider, tag: 1, maximum: TimerTimeline.never)
        configure(systemSleepSlider, tag: 2, maximum: TimerTimeline.never)
        configure(diskSleepSlider, tag: 3, maximum: TimerTimeline.never)

        let timeline = NSStackView(views: [
            sliderRow(title: "Screen Saver", slider: screenSaverSlider, value: screenSaverValue),
            sliderRow(title: "Display Off", slider: displaySleepSlider, value: displaySleepValue),
            sliderRow(title: "Computer Sleep", slider: systemSleepSlider, value: systemSleepValue),
        ])
        timeline.orientation = .vertical
        timeline.alignment = .leading
        timeline.spacing = 12

        let apply = NSButton(title: "Apply Changes", target: self, action: #selector(applyChanges))
        apply.bezelStyle = .rounded
        apply.keyEquivalent = "\\r"

        let content = NSStackView(views: [
            heading(),
            sourceControl,
            timeline,
            sliderRow(title: "Disk Sleep", slider: diskSleepSlider, value: diskSleepValue),
            wakeForNetwork,
            NSStackView(views: [apply, status]),
            footnote(),
        ])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 16
        content.edgeInsets = NSEdgeInsets(top: 24, left: 28, bottom: 24, right: 28)
        content.setHuggingPriority(.required, for: .vertical)

        let view = NSView()
        view.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            content.topAnchor.constraint(equalTo: view.topAnchor),
            content.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            view.widthAnchor.constraint(greaterThanOrEqualToConstant: 520),
        ])
        self.view = view
        reload()
    }

    @objc private func sourceChanged() {
        source = PowerSource.allCases[sourceControl.selectedSegment]
        render()
    }

    @objc private func applyChanges() {
        let updated = PowerSettings(
            displaySleep: TimerTimeline.minutes(for: timeline.displaySleep),
            systemSleep: TimerTimeline.minutes(for: timeline.systemSleep),
            diskSleep: minutes(in: diskSleepSlider),
            wakeForNetwork: wakeForNetwork.state == .on
        )

        do {
            try client.apply(updated, to: source)
            try applyScreenSaverConfiguration()
            settings[source] = updated
            status.stringValue = "Saved \(source.label.lowercased()) settings."
        } catch {
            status.stringValue = error.localizedDescription
        }
    }

    private func applyScreenSaverConfiguration() throws {
        let current = ScreenSaverAutomation.configuration
        let configuration = ScreenSaverAutomationConfiguration(
            isEnabled: true,
            batteryMinutes: source == .battery ? TimerTimeline.minutes(for: timeline.screenSaver) : current.batteryMinutes,
            powerAdapterMinutes: source == .ac ? TimerTimeline.minutes(for: timeline.screenSaver) : current.powerAdapterMinutes
        )

        ScreenSaverAutomation.save(configuration)
        try automationAgent.setEnabled(configuration.isEnabled, monitorURL: monitorURL)
        try ScreenSaverAutomation.applyCurrentPowerSource()
    }

    private func reload() {
        do {
            settings = try client.currentSettings()
            status.stringValue = ""
        } catch {
            status.stringValue = error.localizedDescription
        }
        render()
    }

    private func render() {
        guard let current = settings[source] else { return }
        let configuration = ScreenSaverAutomation.configuration
        let timeline = TimerTimeline(
            screenSaverMinutes: source == .battery ? configuration.batteryMinutes : configuration.powerAdapterMinutes,
            displaySleepMinutes: current.displaySleep,
            systemSleepMinutes: current.systemSleep
        ).adjusted(for: .systemSleep)
        render(timeline)
        renderDiskSleep(current.diskSleep)
        wakeForNetwork.state = current.wakeForNetwork ? .on : .off
    }

    private func heading() -> NSView {
        let title = NSTextField(labelWithString: "Power Management")
        title.font = .preferredFont(forTextStyle: .title2)
        let subtitle = NSTextField(wrappingLabelWithString: "Set idle timers without opening Terminal. Changes require your administrator password.")
        subtitle.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [title, subtitle])
        stack.orientation = .vertical
        stack.spacing = 4
        return stack
    }

    private func footnote() -> NSView {
        let note = NSTextField(wrappingLabelWithString: "The first three timers stay ordered. Disk sleep is independent. To keep background work running after the display turns off, set computer sleep to Never.")
        note.font = .preferredFont(forTextStyle: .caption1)
        note.textColor = .secondaryLabelColor
        note.maximumNumberOfLines = 0
        return note
    }

    @objc private func timerChanged(_ slider: NSSlider) {
        let value = Int(slider.doubleValue.rounded())
        switch slider.tag {
        case 0:
            render(TimerTimeline(screenSaver: value, displaySleep: timeline.displaySleep, systemSleep: timeline.systemSleep).adjusted(for: .screenSaver))
        case 1:
            render(TimerTimeline(screenSaver: timeline.screenSaver, displaySleep: value, systemSleep: timeline.systemSleep).adjusted(for: .displaySleep))
        case 2:
            render(TimerTimeline(screenSaver: timeline.screenSaver, displaySleep: timeline.displaySleep, systemSleep: value).adjusted(for: .systemSleep))
        default:
            renderDiskSleep(minutes(in: slider))
        }
    }

    private var timeline: TimerTimeline {
        TimerTimeline(
            screenSaver: Int(screenSaverSlider.doubleValue.rounded()),
            displaySleep: Int(displaySleepSlider.doubleValue.rounded()),
            systemSleep: Int(systemSleepSlider.doubleValue.rounded())
        )
    }

    private func configure(_ slider: NSSlider, tag: Int, maximum: Int) {
        slider.minValue = 1
        slider.maxValue = Double(maximum)
        slider.tag = tag
        slider.target = self
        slider.action = #selector(timerChanged)
        slider.isContinuous = true
        slider.widthAnchor.constraint(equalToConstant: 420).isActive = true
    }

    private func sliderRow(title: String, slider: NSSlider, value: NSTextField) -> NSView {
        let title = NSTextField(labelWithString: title)
        value.alignment = .right
        value.setContentHuggingPriority(.required, for: .horizontal)

        let header = NSStackView(views: [title, value])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.distribution = .fill

        let row = NSStackView(views: [header, slider])
        row.orientation = .vertical
        row.alignment = .leading
        row.spacing = 2
        header.widthAnchor.constraint(equalTo: slider.widthAnchor).isActive = true
        return row
    }

    private func render(_ timeline: TimerTimeline) {
        screenSaverSlider.doubleValue = Double(timeline.screenSaver)
        displaySleepSlider.doubleValue = Double(timeline.displaySleep)
        systemSleepSlider.doubleValue = Double(timeline.systemSleep)
        screenSaverValue.stringValue = timerTitle(minutes: TimerTimeline.minutes(for: timeline.screenSaver))
        displaySleepValue.stringValue = timerTitle(minutes: TimerTimeline.minutes(for: timeline.displaySleep))
        systemSleepValue.stringValue = timerTitle(minutes: TimerTimeline.minutes(for: timeline.systemSleep))
    }

    private func renderDiskSleep(_ minutes: Int) {
        diskSleepSlider.doubleValue = Double(TimerTimeline.sliderValue(for: minutes))
        diskSleepValue.stringValue = timerTitle(minutes: minutes)
    }

    private var monitorURL: URL {
        Bundle(for: PowerManagementPreferencePane.self)
            .bundleURL
            .appending(path: "Contents/Resources/PowerManagementMonitor")
    }

    private func minutes(in slider: NSSlider) -> Int {
        TimerTimeline.minutes(for: Int(slider.doubleValue.rounded()))
    }

    private func timerTitle(minutes: Int) -> String {
        switch minutes {
        case 0: "Never"
        case 1: "1 minute"
        case 60: "1 hour"
        case 120: "2 hours"
        default: "\(minutes) minutes"
        }
    }
}
