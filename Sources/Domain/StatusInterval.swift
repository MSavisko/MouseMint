import Foundation

/// These are status-query intervals, independent of the mouse's USB report rate.
enum StatusInterval {
    static let seconds = [2, 3, 5, 8, 10]
    static let defaultSeconds = 5

    static func validated(_ value: Int) -> Int {
        seconds.contains(value) ? value : defaultSeconds
    }

    static func sliderIndex(for seconds: Int) -> Int {
        Self.seconds.firstIndex(of: validated(seconds))!
    }

    static func seconds(at index: Double) -> Int {
        guard index.isFinite else { return defaultSeconds }
        let clamped = min(max(index.rounded(), 0), Double(seconds.count - 1))
        return seconds[Int(clamped)]
    }
}

protocol StatusIntervalPreferences: AnyObject { var seconds: Int { get set } }
