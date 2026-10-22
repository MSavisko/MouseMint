import AppKit

private final class PreviewBackend: NaturalScrollingBackend {
    var state = NaturalScrollingState(preference: false, live: false)
    var writes = 0
    func read() -> NaturalScrollingState { state }
    func setEnabled(_ enabled: Bool) {
        writes += 1
        state = NaturalScrollingState(preference: enabled, live: enabled)
    }
}

@main struct SettingsTests {
    static func main() throws {
        // A separate process verifies that the preference survives relaunch.
        if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--verify-saved" {
            let defaults = UserDefaults(suiteName: CommandLine.arguments[2])!
            precondition(!SavedScrollingPreferences(defaults: defaults).automaticallySwitch)
            precondition(StatusPollingPreferences(defaults: defaults).seconds == 10)
            return
        }
        let domain = "local.keychroncharge.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain); defaults.synchronize() }
        let preferences = SavedScrollingPreferences(defaults: defaults)
        precondition(preferences.automaticallySwitch) // Preserve existing behavior on upgrade.
        let pollingPreferences = StatusPollingPreferences(defaults: defaults)
        precondition(pollingPreferences.seconds == 5)
        for invalid in [0, 1, 4, -1, 100] {
            pollingPreferences.seconds = invalid
            precondition(pollingPreferences.seconds == 5)
        }
        precondition(StatusInterval.seconds(at: .nan) == 5)
        precondition(StatusInterval.seconds(at: -100) == 2)
        precondition(StatusInterval.seconds(at: 100) == 10)

        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        app.finishLaunching()
        let backend = PreviewBackend()
        let controller = AutomaticNaturalScrolling(backend: backend, preferences: preferences)
        var timerRequests = 0
        let polling = StatusPolling(preferences: pollingPreferences) { timerRequests += 1 }
        polling.start()
        precondition(polling.timer?.timeInterval == 5)
        let clipboard = NSPasteboard.withUniqueName()
        defer { clipboard.releaseGlobally() }
        var report = "Keychron M3\nBattery: 100%\nNatural Scrolling: Off"
        var refreshRequests = 0
        var settings: SettingsWindow!
        settings = SettingsWindow(automaticChanged: { enabled in
            controller.setAutomatic(enabled)
            settings.update(from: controller, statusInterval: polling.seconds)
        }, naturalChanged: { enabled in
            controller.setManual(enabled)
            settings.update(from: controller, statusInterval: polling.seconds)
        }, intervalChanged: { seconds in
            polling.setSeconds(seconds)
            settings.update(from: controller, statusInterval: polling.seconds)
        }, refreshRequested: {
            refreshRequests += 1
        }, diagnostics: {
            report
        }, pasteboard: clipboard)
        settings.update(from: controller, statusInterval: polling.seconds)
        precondition(settings.selectedPane == .general)
        // Exercise all five slider positions and the same scheduler used by
        // the app. Changing the interval replaces, rather than adds, a timer.
        for (index, seconds) in StatusInterval.seconds.enumerated() {
            let previous = polling.timer!
            settings.intervalSlider.doubleValue = Double(index)
            app.sendAction(settings.intervalSlider.action!, to: settings.intervalSlider.target, from: settings.intervalSlider)
            precondition(!previous.isValid)
            precondition(polling.seconds == seconds && polling.timer?.timeInterval == Double(seconds))
            precondition(settings.intervalLabel.stringValue.contains("\(seconds) seconds"))
        }
        // Verify actual run-loop delivery at the minimum supported interval,
        // then ensure the replaced two-second timer no longer fires.
        polling.setSeconds(2)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 2.2))
        precondition(timerRequests == 1)
        polling.setSeconds(10)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 2.2))
        precondition(timerRequests == 1)
        settings.update(from: controller, statusInterval: polling.seconds)
        polling.timer?.invalidate()
        precondition(settings.automaticSwitch.state == .on)
        precondition(!settings.naturalSwitch.isEnabled && settings.naturalSwitch.state == .off)

        // Exercise the actual controls' target/actions against an injected
        // backend, without altering this Mac's scroll direction.
        settings.automaticSwitch.state = .off
        app.sendAction(settings.automaticSwitch.action!, to: settings.automaticSwitch.target, from: settings.automaticSwitch)
        precondition(!controller.isAutomatic && settings.naturalSwitch.isEnabled && backend.writes == 0)
        defaults.synchronize()
        let child = Process()
        child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        child.arguments = ["--verify-saved", domain]
        try child.run()
        child.waitUntilExit()
        precondition(child.terminationStatus == 0)
        settings.naturalSwitch.state = .on
        app.sendAction(settings.naturalSwitch.action!, to: settings.naturalSwitch.target, from: settings.naturalSwitch)
        precondition(controller.state.live == true && backend.writes == 1)
        controller.update(connection: .connected)
        precondition(controller.state.live == true && backend.writes == 1)

        settings.window!.appearance = NSAppearance(named: .aqua)
        settings.window!.orderFront(nil)
        precondition(settings.window!.toolbar!.items.map(\.label) == ["General", "Natural Scrolling", "Diagnostics", "About"])
        precondition(!settings.window!.toolbar!.allowsUserCustomization)
        // Select every pane through its real toolbar target/action. Switching
        // panes must not change scrolling, and copy uses a private pasteboard.
        let writesBeforeNavigation = backend.writes
        for pane in SettingsWindow.Pane.allCases {
            let toolbarItem = settings.window!.toolbar!.items.first { $0.itemIdentifier == pane.identifier }!
            app.sendAction(toolbarItem.action!, to: toolbarItem.target, from: toolbarItem)
            precondition(settings.selectedPane == pane)
            precondition(settings.window!.toolbar!.selectedItemIdentifier == pane.identifier)
            try render(settings, name: pane.rawValue)
        }
        precondition(backend.writes == writesBeforeNavigation)
        settings.selectPane(.diagnostics)
        precondition(settings.diagnosticsText.string == report && !settings.diagnosticsText.isEditable)
        app.sendAction(settings.refreshButton.action!, to: settings.refreshButton.target, from: settings.refreshButton)
        precondition(refreshRequests == 1)
        settings.update(from: controller, refreshing: true, statusInterval: polling.seconds)
        precondition(!settings.refreshButton.isEnabled)
        report = "Keychron M3\nBattery: 99%\nNatural Scrolling: On"
        settings.update(from: controller, statusInterval: polling.seconds)
        precondition(settings.refreshButton.isEnabled && settings.diagnosticsText.string == report)
        app.sendAction(settings.copyButton.action!, to: settings.copyButton.target, from: settings.copyButton)
        precondition(clipboard.string(forType: .string) == report)
        precondition(settings.copyStatus.stringValue == "Diagnostics copied.")
        try render(settings, name: "diagnostics-copied")
        settings.window!.orderOut(nil)

        settings.selectPane(.naturalScrolling)
        settings.automaticSwitch.state = .on
        app.sendAction(settings.automaticSwitch.action!, to: settings.automaticSwitch.target, from: settings.automaticSwitch)
        controller.update(connection: .connected)
        settings.update(from: controller, statusInterval: polling.seconds)
        precondition(controller.isAutomatic && !settings.naturalSwitch.isEnabled && settings.naturalSwitch.state == .off)
        precondition(backend.writes == 2)
        print("Settings panes, all slider intervals, timer delivery/replacement, clipboard, scrolling controls, and persistence passed.")
    }

    private static func render(_ settings: SettingsWindow, name: String) throws {
        // Render this test window's complete view tree, including its native
        // toolbar, rather than capturing the desktop or another application.
        let content = settings.window!.contentView!.superview!
        content.layoutSubtreeIfNeeded()
        settings.window!.displayIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        let representation = content.bitmapImageRepForCachingDisplay(in: content.bounds)!
        content.cacheDisplay(in: content.bounds, to: representation)
        let preview = NSImage(size: content.bounds.size)
        preview.lockFocus()
        NSColor.windowBackgroundColor.setFill()
        content.bounds.fill()
        NSImage(cgImage: representation.cgImage!, size: content.bounds.size).draw(in: content.bounds)
        preview.unlockFocus()
        let png = NSBitmapImageRep(data: preview.tiffRepresentation!)!.representation(using: .png, properties: [:])!
        try png.write(to: URL(fileURLWithPath: ".build/settings-\(name).png"))
    }
}
