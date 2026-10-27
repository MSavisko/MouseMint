import AppKit

final class NativeAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let coordinator: AppCoordinator
    private let polling: PollingSchedulerAdapter
    private let inspection: Bool
    private let showSettings: Bool
    private var item: NSStatusItem!
    private var statusMenu: StatusMenu!
    private var settingsWindow: SettingsWindow?

    init(coordinator: AppCoordinator, polling: PollingSchedulerAdapter, inspection: Bool, showSettings: Bool) {
        self.coordinator = coordinator; self.polling = polling
        self.inspection = inspection; self.showSettings = showSettings
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        item.button?.imagePosition = .imageLeading
        statusMenu = StatusMenu(button: item.button!, settings: { [weak self] in self?.openSettings() }, quit: { NSApp.terminate(nil) })
        item.menu = statusMenu.menu
        statusMenu.menu.delegate = self
        coordinator.onChange = { [weak self] state in
            guard let self else { return }
            self.updateUI()
            if self.inspection, !state.refreshing, state.reading != nil || state.failure != nil { self.finishInspection() }
        }
        updateUI()
        coordinator.start()
        if showSettings { openSettings() }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(woke), name: NSWorkspace.didWakeNotification, object: nil)
    }
    func applicationWillTerminate(_ notification: Notification) { coordinator.stop() }
    @objc private func woke() { coordinator.refresh() }
    func menuWillOpen(_ menu: NSMenu) { updateUI(); coordinator.refresh() }

    private func updateUI() {
        let state = coordinator.snapshot
        statusMenu.render(state)
        settingsWindow?.update(state: state.scrolling, refreshing: state.refreshing, statusInterval: state.interval)
    }
    private var diagnostics: String {
        DiagnosticReport.make(coordinator.snapshot, version: AppVersion.description, system: ProcessInfo.processInfo.operatingSystemVersionString)
    }
    private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow(automaticChanged: coordinator.setAutomatic,
                naturalChanged: coordinator.setNaturalScrolling, intervalChanged: coordinator.setInterval,
                refreshRequested: coordinator.refresh, diagnostics: { [weak self] in self?.diagnostics ?? "No diagnostic reading available." })
        }
        coordinator.inspectScrolling()
        updateUI()
        settingsWindow?.present()
    }
    private func finishInspection() {
        print("Menu bar: \(statusMenu.button.title)")
        print("Mode icon: \(statusMenu.button.image?.accessibilityDescription ?? "missing")")
        for row in statusMenu.menu.items where !row.isSeparatorItem { print("\(row.title) [icon: \(row.image?.accessibilityDescription ?? "none")]") }
        if let settings = settingsWindow {
            print("Settings window: \(settings.window?.title ?? "missing")")
            print("Settings panes: \(settings.window?.toolbar?.items.map(\.label).joined(separator: ", ") ?? "missing")")
            print("Selected pane: \(settings.selectedPane.title)")
            print("Status interval: \(polling.seconds) seconds; timer: \(polling.timer?.timeInterval ?? 0)")
            print("Diagnostics actions: \(settings.refreshButton.title), \(settings.copyButton.title)")
            print("Diagnostics preview:\n\(settings.diagnosticsText.string)")
            print("Automatic switch: \(settings.automaticSwitch.state == .on ? "On" : "Off")")
            print("Manual switch: \(settings.naturalSwitch.state == .on ? "On" : "Off"); editable: \(settings.naturalSwitch.isEnabled)")
        }
        exit(coordinator.snapshot.reading == nil ? 1 : 0)
    }
    deinit { NSWorkspace.shared.notificationCenter.removeObserver(self) }
}
