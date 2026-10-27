import AppKit

final class StatusMenu: NSObject {
    let menu = NSMenu()
    let button: NSButton
    private let settings: () -> Void
    private let quit: () -> Void
    private let formatDate: (Date) -> String
    init(button: NSButton, settings: @escaping () -> Void, quit: @escaping () -> Void,
         formatDate: @escaping (Date) -> String = { $0.formatted(date: .omitted, time: .standard) }) {
        self.button = button; self.settings = settings; self.quit = quit; self.formatDate = formatDate
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

    func render(_ state: AppSnapshot) {
        let reading = state.reading
        let errorMessage = state.failure.map { String(describing: $0) }
        let connectionUnavailable = state.disconnected
        menu.removeAllItems()
        label("Keychron M3", symbol: "computermouse")
        if let reading {
            let status = reading.status
            let level = status.map { "\($0.percentage)%" } ?? "—"
            button.title = " \(level)"
            button.image = ModeIcon.image(for: reading.mode)
            button.toolTip = "Keychron M3: \(level) · \(reading.mode.title) · \(status?.powerDescription ?? "Battery unavailable")"
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
            label("Updated: \(formatDate(reading.date))", symbol: "clock")
        } else {
            if connectionUnavailable {
                button.title = " Not connected"
                button.image = ModeIcon.image(for: nil)
                button.toolTip = "Keychron M3 is not connected. Wake the mouse or check its connection."
                label("Status: Not connected", symbol: "xmark.circle")
            } else if let errorMessage {
                button.title = " Read error"
                button.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Mouse status unavailable")
                button.toolTip = errorMessage
                label("Status: Unable to read mouse", symbol: "exclamationmark.triangle")
            } else {
                button.title = " Checking…"
                button.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "Checking mouse connection")
                button.toolTip = "Checking Keychron M3…"
                label("Checking mouse connection…", symbol: "ellipsis.circle")
            }
        }
        menu.addItem(.separator())
        label(state.scrolling.title, symbol: state.scrolling.error == nil ? "arrow.up.arrow.down" : "exclamationmark.triangle")
        menu.addItem(.separator())
        action("Settings…", #selector(didChooseSettings), symbol: "gearshape", key: ",")
        action("Quit MouseMint", #selector(didChooseQuit), symbol: "power", key: "q")
    }


    @objc private func didChooseSettings() { settings() }
    @objc private func didChooseQuit() { quit() }
}
