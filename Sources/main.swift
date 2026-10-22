import AppKit
import Foundation

if CommandLine.arguments.contains("--read-json") {
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
    private var timer: Timer?
    private var reading: MouseReading?
    private var errorMessage: String?
    private var connectionUnavailable = false
    private var refreshing = false
    private let worker = DispatchQueue(label: "local.keychroncharge.usb", qos: .utility)

    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        item.button?.imagePosition = .imageLeading
        item.menu = menu
        menu.delegate = self
        updateUI()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.refresh() }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(woke),
            name: NSWorkspace.didWakeNotification, object: nil)
    }

    @objc private func woke() { refresh() }
    func menuWillOpen(_ menu: NSMenu) { updateUI(); refresh() }

    @objc private func refresh() {
        guard !refreshing else { return }
        refreshing = true
        worker.async { [weak self] in
            let result = Result { try MouseReader.read() }
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
                    case .disconnected?, .receiverUnavailable?: self.connectionUnavailable = true
                    default: self.connectionUnavailable = false
                    }
                }
                self.updateUI()
                if CommandLine.arguments.contains("--check-ui") {
                    print("Menu bar: \(self.item.button?.title ?? "missing")")
                    print("Mode icon: \(self.item.button?.image?.accessibilityDescription ?? "missing")")
                    for row in self.menu.items where !row.isSeparatorItem { print(row.title) }
                    exit(self.reading == nil ? 1 : 0)
                }
            }
        }
    }

    private func label(_ text: String) {
        let row = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        menu.addItem(row)
    }

    private func action(_ title: String, _ selector: Selector, key: String = "") {
        let row = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        row.target = self
        menu.addItem(row)
    }

    private func updateUI() {
        menu.removeAllItems()
        label("Keychron M3")
        if let reading {
            let status = reading.status
            let level = status.map { "\($0.percentage)%" } ?? "—"
            item.button?.title = " \(level)"
            item.button?.image = ModeIcon.image(for: reading.mode)
            item.button?.toolTip = "Keychron M3: \(level) · \(reading.mode.title) · \(status?.powerDescription ?? "Battery unavailable")"
            label("Connection: \(reading.mode.title)")
            label("Battery: \(status.map { "\($0.percentage)%" } ?? "Waiting for macOS")")
            label("Status: \(status?.powerDescription ?? "Battery unavailable")")
            label("Updated: \(reading.date.formatted(date: .omitted, time: .standard))")
        } else {
            if connectionUnavailable {
                item.button?.title = " Not connected"
                item.button?.image = ModeIcon.image(for: nil)
                item.button?.toolTip = "Keychron M3 is not connected. Wake the mouse or check its connection."
                label("Status: Not connected")
                label("Wake the mouse or check its cable, receiver, or Bluetooth.")
            } else if let errorMessage {
                item.button?.title = " Read error"
                item.button?.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Mouse status unavailable")
                item.button?.toolTip = errorMessage
                label("Status: Unable to read mouse")
                label(errorMessage)
            } else {
                item.button?.title = " Checking…"
                item.button?.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "Checking mouse connection")
                item.button?.toolTip = "Checking Keychron M3…"
                label("Checking mouse connection…")
            }
        }
        menu.addItem(.separator())
        action("Refresh Now", #selector(refresh), key: "r")
        action("Copy Diagnostics", #selector(copyDiagnostics))
        action("About Keychron Charge", #selector(about))
        menu.addItem(.separator())
        action("Quit Keychron Charge", #selector(quit), key: "q")
    }

    @objc private func copyDiagnostics() {
        var text = "Keychron Charge 1.1\n"
        if let reading {
            text += "Connection: \(reading.mode.title)\nProduct ID: \(String(format: "%04X", reading.productID))\n"
            if let status = reading.status {
                text += "Battery: \(status.percentage)%\nPower state: \(status.powerState.map(String.init) ?? "unknown") (\(status.powerDescription))\n"
            } else { text += "Battery unavailable\n" }
            text += "Read at: \(reading.date.ISO8601Format())\n"
            text += reading.mode == .bluetooth ? "Source: macOS accessory battery service" : "Report: " + reading.rawReport.map { String(format: "%02x", $0) }.joined(separator: " ")
        } else { text += errorMessage ?? "No reading yet" }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func about() {
        let alert = NSAlert()
        alert.messageText = "Keychron Charge"
        alert.informativeText = "A small battery monitor for Keychron M3.\n\nSupports USB cable, USB-C receiver, and Bluetooth. Checks the connection every five seconds. Bluetooth percentage comes from macOS.\n\nNo network connection or mouse configuration changes."
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
