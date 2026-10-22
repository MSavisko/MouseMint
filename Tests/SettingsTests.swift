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
            return
        }
        let domain = "local.keychroncharge.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain); defaults.synchronize() }
        let preferences = SavedScrollingPreferences(defaults: defaults)
        precondition(preferences.automaticallySwitch) // Preserve existing behavior on upgrade.

        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        app.finishLaunching()
        let backend = PreviewBackend()
        let controller = AutomaticNaturalScrolling(backend: backend, preferences: preferences)
        var settings: SettingsWindow!
        settings = SettingsWindow(automaticChanged: { enabled in
            controller.setAutomatic(enabled)
            settings.update(from: controller)
        }, naturalChanged: { enabled in
            controller.setManual(enabled)
            settings.update(from: controller)
        })
        settings.update(from: controller)
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

        let content = settings.window!.contentView!
        settings.window!.appearance = NSAppearance(named: .aqua)
        settings.window!.orderFront(nil)
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
        try png.write(to: URL(fileURLWithPath: ".build/settings-preview.png"))
        settings.window!.orderOut(nil)

        settings.automaticSwitch.state = .on
        app.sendAction(settings.automaticSwitch.action!, to: settings.automaticSwitch.target, from: settings.automaticSwitch)
        controller.update(connection: .connected)
        settings.update(from: controller)
        precondition(controller.isAutomatic && !settings.naturalSwitch.isEnabled && settings.naturalSwitch.state == .off)
        precondition(backend.writes == 2)
        print("Settings controls, manual mode, re-enabling, and preference persistence across processes passed.")
    }
}
