import Foundation

struct ScrollingSnapshot {
    let state: NaturalScrollingState
    let automatic: Bool
    let failure: Error?
}

struct AppSnapshot {
    var configuredDeviceName = "Mouse"
    var deviceName: String { reading?.deviceName ?? configuredDeviceName }
    var reading: MouseReading?
    var failure: Error?
    var connection: MouseConnectionState = .unknown
    var refreshing = false
    var interval: Int
    var scrolling: ScrollingSnapshot
    var disconnected: Bool {
        switch failure as? MouseReadError {
        case .disconnected?, .receiverDisconnected?: return true
        default: return false
        }
    }
}
