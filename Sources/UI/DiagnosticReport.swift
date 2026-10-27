import Foundation

enum DiagnosticReport {
    static func make(_ state: AppSnapshot, version: String, system: String) -> String {
        let reading = state.reading
        let errorMessage = state.failure.map { String(describing: $0) }
        var text = "MouseMint — \(version)\n"
        text += "macOS: \(system)\n"
        text += "Status check interval: \(state.interval) seconds\n"
        if let reading {
            text += "Connection: \(reading.mode.title)\nProduct ID: \(String(format: "%04X", reading.productID))\n"
            if let status = reading.status {
                text += "Battery: \(status.percentage)%\nPower state: \(status.powerState.map(String.init) ?? "unknown") (\(status.powerDescription))\n"
            } else { text += "Battery unavailable\n" }
            text += "Read at: \(reading.date.ISO8601Format())\n"
            text += reading.mode == .bluetooth ? "Source: macOS accessory battery service" : "Report: " + reading.rawReport.map { String(format: "%02x", $0) }.joined(separator: " ")
        } else { text += errorMessage ?? "No reading yet" }
        text += "\n\(state.scrolling.title)\n"
        text += "Automatic switching: \(state.scrolling.automatic ? "On" : "Off")\n"
        text += "Natural Scrolling saved: \(state.scrolling.state.preference.map { $0 ? "On" : "Off" } ?? "Unavailable")\n"
        text += "Natural Scrolling live: \(state.scrolling.state.live.map { $0 ? "On" : "Off" } ?? "Unavailable")\n"
        if let error = state.scrolling.error { text += "Scrolling error: \(error)\n" }
        return text
    }

}
