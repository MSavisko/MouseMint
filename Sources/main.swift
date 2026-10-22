import AppKit
import Foundation

if CommandLine.arguments.contains("--scroll-status") {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    print(String(decoding: try encoder.encode(SystemNaturalScrolling().read()), as: UTF8.self))
} else if CommandLine.arguments.contains("--read-json") {
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let reading = try MouseReader.read()
        print(String(decoding: try encoder.encode(reading), as: UTF8.self))
    } catch {
        fputs("\(error)\n", stderr)
        exit(1)
    }
} else {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var item: NSStatusItem!
    private let menu = NSMenu()
    private lazy var polling = StatusPolling { [weak self] in self?.refresh() }
    private var reading: MouseReading?
    private var errorMessage: String?
    private var connectionUnavailable = false
    private var refreshing = false
    private let naturalScrolling = AutomaticNaturalScrolling()
    private var settingsWindow: SettingsWindow?
    private let worker = DispatchQueue(label: "local.keychroncharge.usb", qos: .utility)

    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        item.button?.imagePosition = .imageLeading
        item.menu = menu
        menu.delegate = self
        updateUI()
        refresh()
        if CommandLine.arguments.contains("--settings") { openSettings() }
        polling.start()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(woke),
            name: NSWorkspace.didWakeNotification, object: nil)
    }

    @objc private func woke() { refresh() }
    func menuWillOpen(_ menu: NSMenu) { updateUI(); refresh() }

    @objc private func refresh() {
        guard !refreshing else { return }
        refreshing = true
        updateUI()
        worker.async { [weak self] in
            let result = Result { try MouseReader.read() }
            let scrollConnection: MouseConnectionState
            switch result {
            case .success: scrollConnection = .connected
            case .failure(let error):
                scrollConnection = (error as? MouseReadError)?.scrollingConnection(directMousePresent: MouseReader.hasDirectConnection()) ?? .unknown
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.refreshing = false
                switch result {
                case .success(let value):
                    self.reading = value
                    self.errorMessage = nil
                    self.connectionUnavailable = false
                case .failure(let error):
                    self.reading = nil
                    self.errorMessage = String(describing: error)
                    switch error as? MouseReadError {
                    case .disconnected?, .receiverDisconnected?: self.connectionUnavailable = true
                    default: self.connectionUnavailable = false
                    }
                }
                // Inspection commands remain read-only; normal app refreshes
                // apply the user's requested connection-based system setting.
                if CommandLine.arguments.contains("--check-ui") {
                    self.naturalScrolling.refreshStatus()
                } else {
                    self.naturalScrolling.update(connection: scrollConnection)
                }
                self.updateUI()
                if CommandLine.arguments.contains("--check-ui") {
                    print("Menu bar: \(self.item.button?.title ?? "missing")")
                    print("Mode icon: \(self.item.button?.image?.accessibilityDescription ?? "missing")")
                    for row in self.menu.items where !row.isSeparatorItem {
                        print("\(row.title) [icon: \(row.image?.accessibilityDescription ?? "none")]")
                    }
                    if let settings = self.settingsWindow {
                        print("Settings window: \(settings.window?.title ?? "missing")")
                        print("Settings panes: \(settings.window?.toolbar?.items.map(\.label).joined(separator: ", ") ?? "missing")")
                        print("Selected pane: \(settings.selectedPane.title)")
                        print("Status interval: \(self.polling.seconds) seconds; timer: \(self.polling.timer?.timeInterval ?? 0)")
                        print("Diagnostics actions: \(settings.refreshButton.title), \(settings.copyButton.title)")
                        print("Diagnostics preview:\n\(settings.diagnosticsText.string)")
                        print("Automatic switch: \(settings.automaticSwitch.state == .on ? "On" : "Off")")
                        print("Manual switch: \(settings.naturalSwitch.state == .on ? "On" : "Off"); editable: \(settings.naturalSwitch.isEnabled)")
                    }
                    exit(self.reading == nil ? 1 : 0)
                }
            }
        }
    }

    private func menuImage(_ symbol: String, description: String) -> NSImage? {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .regular))
        image?.isTemplate = true
        image?.size = NSSize(width: 16, height: 16)
        return image
    }

    @discardableResult
    private func label(_ text: String, symbol: String? = nil) -> NSMenuItem {
        let row = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        if let symbol { row.image = menuImage(symbol, description: text) }
        menu.addItem(row)
        return row
    }

    private func action(_ title: String, _ selector: Selector, symbol: String, key: String = "") {
        let row = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        row.image = menuImage(symbol, description: title)
        row.target = self
        menu.addItem(row)
    }

    private func updateUI() {
        settingsWindow?.update(from: naturalScrolling, refreshing: refreshing, statusInterval: polling.seconds)
        menu.removeAllItems()
        label("Keychron M3", symbol: "computermouse")
        if let reading {
            let status = reading.status
            let level = status.map { "\($0.percentage)%" } ?? "—"
            item.button?.title = " \(level)"
            item.button?.image = ModeIcon.image(for: reading.mode)
            item.button?.toolTip = "Keychron M3: \(level) · \(reading.mode.title) · \(status?.powerDescription ?? "Battery unavailable")"
            let connection = label("Connection: \(reading.mode.title)")
            connection.image = ModeIcon.image(for: reading.mode)
            connection.image?.size = NSSize(width: 16, height: 16)
            let batterySymbol: String
            switch status?.percentage ?? 0 {
            case ..<15: batterySymbol = "battery.0percent"
            case ..<40: batterySymbol = "battery.25percent"
            case ..<65: batterySymbol = "battery.50percent"
            case ..<90: batterySymbol = "battery.75percent"
            default: batterySymbol = "battery.100percent"
            }
            label("Battery: \(status.map { "\($0.percentage)%" } ?? "Waiting for macOS")", symbol: batterySymbol)
            let statusSymbol = status?.powerState == 1 ? "bolt.fill" : status?.powerState == 2 ? "checkmark.circle" : "info.circle"
            label("Status: \(status?.powerDescription ?? "Battery unavailable")", symbol: statusSymbol)
            label("Updated: \(reading.date.formatted(date: .omitted, time: .standard))", symbol: "clock")
        } else {
            if connectionUnavailable {
                item.button?.title = " Not connected"
                item.button?.image = ModeIcon.image(for: nil)
                item.button?.toolTip = "Keychron M3 is not connected. Wake the mouse or check its connection."
                label("Status: Not connected", symbol: "xmark.circle")
            } else if let errorMessage {
                item.button?.title = " Read error"
                item.button?.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Mouse status unavailable")
                item.button?.toolTip = errorMessage
                label("Status: Unable to read mouse", symbol: "exclamationmark.triangle")
            } else {
                item.button?.title = " Checking…"
                item.button?.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "Checking mouse connection")
                item.button?.toolTip = "Checking Keychron M3…"
                label("Checking mouse connection…", symbol: "ellipsis.circle")
            }
        }
        menu.addItem(.separator())
        label(naturalScrolling.menuTitle, symbol: naturalScrolling.errorMessage == nil ? "arrow.up.arrow.down" : "exclamationmark.triangle")
        menu.addItem(.separator())
        action("Settings…", #selector(openSettings), symbol: "gearshape", key: ",")
        action("Quit Keychron Charge", #selector(quit), symbol: "power", key: "q")
    }

    private var diagnosticsReport: String {
        var text = "Keychron Charge — \(AppVersion.description)\n"
        text += "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
        text += "Status check interval: \(polling.seconds) seconds\n"
        if let reading {
            text += "Connection: \(reading.mode.title)\nProduct ID: \(String(format: "%04X", reading.productID))\n"
            if let status = reading.status {
                text += "Battery: \(status.percentage)%\nPower state: \(status.powerState.map(String.init) ?? "unknown") (\(status.powerDescription))\n"
            } else { text += "Battery unavailable\n" }
            text += "Read at: \(reading.date.ISO8601Format())\n"
            text += reading.mode == .bluetooth ? "Source: macOS accessory battery service" : "Report: " + reading.rawReport.map { String(format: "%02x", $0) }.joined(separator: " ")
        } else { text += errorMessage ?? "No reading yet" }
        text += "\n\(naturalScrolling.menuTitle)\n"
        text += "Automatic switching: \(naturalScrolling.isAutomatic ? "On" : "Off")\n"
        text += "Natural Scrolling saved: \(naturalScrolling.state.preference.map { $0 ? "On" : "Off" } ?? "Unavailable")\n"
        text += "Natural Scrolling live: \(naturalScrolling.state.live.map { $0 ? "On" : "Off" } ?? "Unavailable")\n"
        if let error = naturalScrolling.errorMessage { text += "Scrolling error: \(error)\n" }
        return text
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow(automaticChanged: { [weak self] enabled in
                guard let self else { return }
                self.naturalScrolling.setAutomatic(enabled)
                self.updateUI()
                if enabled { self.refresh() }
            }, naturalChanged: { [weak self] enabled in
                guard let self else { return }
                self.naturalScrolling.setManual(enabled)
                self.updateUI()
            }, intervalChanged: { [weak self] seconds in
                guard let self else { return }
                self.polling.setSeconds(seconds)
                self.updateUI()
            }, refreshRequested: { [weak self] in
                self?.refresh()
            }, diagnostics: { [weak self] in
                self?.diagnosticsReport ?? "No diagnostic reading available."
            })
        }
        naturalScrolling.refreshStatus()
        settingsWindow?.update(from: naturalScrolling, refreshing: refreshing, statusInterval: polling.seconds)
        settingsWindow?.present()
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
