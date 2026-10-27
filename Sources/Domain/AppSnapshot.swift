import Foundation

struct ScrollingSnapshot {
    let state: NaturalScrollingState
    let automatic: Bool
    let error: String?
    let title: String
    init(_ scrolling: AutomaticNaturalScrolling) {
        state = scrolling.state
        automatic = scrolling.isAutomatic
        error = scrolling.errorMessage
        title = scrolling.menuTitle
    }
}

struct AppSnapshot {
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
