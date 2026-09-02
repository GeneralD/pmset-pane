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
    private let displaySleep = NSPopUpButton()
    private let systemSleep = NSPopUpButton()
    private let diskSleep = NSPopUpButton()
    private let wakeForNetwork = NSButton(checkboxWithTitle: "Wake for network access", target: nil, action: nil)
    private let screenSaverEnabled = NSButton(checkboxWithTitle: "Use a separate screen saver delay for each power source", target: nil, action: nil)
    private let screenSaver = NSPopUpButton()
    private let status = NSTextField(labelWithString: "")
    private let automationAgent = ScreenSaverAutomationAgent()

    override func loadView() {
        sourceControl.target = self
        sourceControl.action = #selector(sourceChanged)
        sourceControl.selectedSegment = 1
        [displaySleep, systemSleep, diskSleep, screenSaver].forEach { menu in
            menu.addItems(withTitles: ["Never", "1 minute", "5 minutes", "10 minutes", "15 minutes", "30 minutes", "1 hour", "2 hours"])
        }

        let form = NSGridView(views: [
            [label("Turn display off after"), displaySleep],
            [label("Put computer to sleep after"), systemSleep],
            [label("Put disks to sleep after"), diskSleep],
            [label("Start screen saver after"), screenSaver],
        ])
        form.rowSpacing = 12
        form.columnSpacing = 24
        form.column(at: 0).xPlacement = .trailing
        form.column(at: 1).xPlacement = .leading

        let apply = NSButton(title: "Apply Changes", target: self, action: #selector(applyChanges))
        apply.bezelStyle = .rounded
        apply.keyEquivalent = "\\r"

        let content = NSStackView(views: [
            heading(),
            sourceControl,
            form,
            wakeForNetwork,
            screenSaverEnabled,
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
        renderScreenSaverAutomation()
    }

    @objc private func sourceChanged() {
        source = PowerSource.allCases[sourceControl.selectedSegment]
        render()
    }

    @objc private func applyChanges() {
        let updated = PowerSettings(
            displaySleep: minutes(in: displaySleep),
            systemSleep: minutes(in: systemSleep),
            diskSleep: minutes(in: diskSleep),
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
            isEnabled: screenSaverEnabled.state == .on,
            batteryMinutes: source == .battery ? minutes(in: screenSaver) : current.batteryMinutes,
            powerAdapterMinutes: source == .ac ? minutes(in: screenSaver) : current.powerAdapterMinutes
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
        select(current.displaySleep, in: displaySleep)
        select(current.systemSleep, in: systemSleep)
        select(current.diskSleep, in: diskSleep)
        wakeForNetwork.state = current.wakeForNetwork ? .on : .off
        renderScreenSaverAutomation()
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
        let note = NSTextField(wrappingLabelWithString: "Display sleep counts from the last input. To keep background work running after the display turns off, set computer sleep to Never.")
        note.font = .preferredFont(forTextStyle: .caption1)
        note.textColor = .secondaryLabelColor
        note.maximumNumberOfLines = 0
        return note
    }

    private func label(_ value: String) -> NSTextField {
        NSTextField(labelWithString: value)
    }

    private func renderScreenSaverAutomation() {
        let configuration = ScreenSaverAutomation.configuration
        screenSaverEnabled.state = configuration.isEnabled ? .on : .off
        select(source == .battery ? configuration.batteryMinutes : configuration.powerAdapterMinutes, in: screenSaver)
    }

    private var monitorURL: URL {
        Bundle(for: PowerManagementPreferencePane.self)
            .bundleURL
            .appending(path: "Contents/Resources/PowerManagementMonitor")
    }

    private func select(_ value: Int, in button: NSPopUpButton) {
        button.selectItem(at: [0, 1, 5, 10, 15, 30, 60, 120].firstIndex(of: value) ?? 0)
    }

    private func minutes(in button: NSPopUpButton) -> Int {
        [0, 1, 5, 10, 15, 30, 60, 120][button.indexOfSelectedItem]
    }
}
