import Foundation
import IOKit.ps
import PowerManagementCore

private final class PowerSourceMonitor {
    private static let callback: IOPowerSourceCallbackType = { _ in
        try? ScreenSaverAutomation.applyCurrentPowerSource()
    }

    func run() {
        try? ScreenSaverAutomation.applyCurrentPowerSource()
        guard let source = IOPSNotificationCreateRunLoopSource(Self.callback, nil)?.takeRetainedValue() else {
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        CFRunLoopRun()
    }
}

PowerSourceMonitor().run()
