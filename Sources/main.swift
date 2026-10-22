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
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.refresh() }
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
                case .failure(let error):
                    self.reading = nil
                    self.errorMessage = String(describing: error)
                }
                self.updateUI()
                if CommandLine.arguments.contains("--check-ui") {
                    print("Menu bar: \(self.item.button?.title ?? "missing")")
                    for row in self.menu.items where !row.isSeparatorItem { print(row.title) }
                    NSApp.terminate(nil)
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
        label("Keychron M3 · USB")
        if let reading {
            let status = reading.status
            item.button?.title = " \(status.percentage)%"
            let icon = status.powerState == 1 ? "battery.100percent.bolt" :
                (status.percentage <= 10 ? "battery.0percent" : status.percentage <= 30 ? "battery.25percent" :
                 status.percentage <= 60 ? "battery.50percent" : status.percentage <= 85 ? "battery.75percent" : "battery.100percent")
            item.button?.image = NSImage(systemSymbolName: icon, accessibilityDescription: "Mouse battery")
            item.button?.toolTip = "Keychron M3: \(status.percentage)% · \(status.powerDescription)"
            label("Battery: \(status.percentage)%")
            label("Status: \(status.powerDescription)")
            label("Updated: \(reading.date.formatted(date: .omitted, time: .standard))")
        } else {
            item.button?.title = " M3 —"
            item.button?.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "Mouse disconnected")
            item.button?.toolTip = errorMessage ?? "Checking Keychron M3…"
            label(errorMessage ?? "Checking mouse…")
        }
        menu.addItem(.separator())
        action("Refresh Now", #selector(refresh), key: "r")
        action("Copy Diagnostics", #selector(copyDiagnostics))
        action("About Keychron Charge", #selector(about))
        menu.addItem(.separator())
        action("Quit Keychron Charge", #selector(quit), key: "q")
    }

    @objc private func copyDiagnostics() {
        var text = "Keychron Charge 1.0\nUSB 3434:D033 · usage 008C:0001\n"
        if let reading {
            text += "Battery: \(reading.status.percentage)%\nPower state: \(reading.status.powerState) (\(reading.status.powerDescription))\n"
            text += "Read at: \(reading.date.ISO8601Format())\n"
            text += "Report: " + reading.rawReport.map { String(format: "%02x", $0) }.joined(separator: " ")
        } else { text += errorMessage ?? "No reading yet" }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func about() {
        let alert = NSAlert()
        alert.messageText = "Keychron Charge"
        alert.informativeText = "A small USB battery monitor for Keychron M3 (3434:D033).\n\nRefreshes every 30 seconds. Battery percentage and power state are reported by the mouse.\n\nNo network connection or mouse configuration changes."
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
