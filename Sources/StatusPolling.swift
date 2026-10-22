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

final class StatusPollingPreferences {
    private let defaults: UserDefaults
    private let key = "statusCheckIntervalSeconds"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var seconds: Int {
        get { StatusInterval.validated(defaults.integer(forKey: key)) }
        set { defaults.set(StatusInterval.validated(newValue), forKey: key) }
    }
}

/// Replacing the timer invalidates the previous schedule. The app separately
/// guards in-flight HID reads, so a timer tick can never queue overlapping work.
final class StatusPolling {
    private(set) var timer: Timer?
    private let preferences: StatusPollingPreferences
    private let refresh: () -> Void
    var seconds: Int { preferences.seconds }

    init(preferences: StatusPollingPreferences = StatusPollingPreferences(), refresh: @escaping () -> Void) {
        self.preferences = preferences
        self.refresh = refresh
    }

    func start() { schedule() }

    func setSeconds(_ seconds: Int) {
        preferences.seconds = seconds
        schedule()
    }

    private func schedule() {
        timer?.invalidate()
        let next = Timer(timeInterval: TimeInterval(seconds), repeats: true) { [weak self] _ in self?.refresh() }
        next.tolerance = 0.1
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }

    deinit { timer?.invalidate() }
}
