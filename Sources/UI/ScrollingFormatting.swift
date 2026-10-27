import Foundation

extension NaturalScrollingError: CustomStringConvertible {
    var description: String {
        switch self {
        case .unavailable: return "This macOS version cannot apply Natural Scrolling automatically."
        case .saveFailed: return "Could not save the Natural Scrolling setting."
        case .applyFailed: return "macOS did not confirm the Natural Scrolling change."
        }
    }
}
extension ScrollingSnapshot {
    var error: String? { failure.map { String(describing: $0) } }
    var title: String {
        if failure != nil { return "Natural Scrolling: Could not update" }
        guard let enabled = state.live else { return "Natural Scrolling: Unavailable" }
        return "Natural Scrolling: \(enabled ? "On" : "Off") (\(automatic ? "automatic" : "manual"))"
    }
}
extension AutomaticNaturalScrolling {
    var errorMessage: String? { failure.map { String(describing: $0) } }
    var menuTitle: String { ScrollingSnapshot(self).title }
}
