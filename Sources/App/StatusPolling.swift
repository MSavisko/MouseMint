import Foundation

/// Replacing the timer invalidates the previous schedule. The app separately
/// guards in-flight HID reads, so a timer tick can never queue overlapping work.
final class StatusPolling {
    private(set) var timer: Timer?
    private let preferences: StatusIntervalPreferences
    private let refresh: () -> Void
    var seconds: Int { preferences.seconds }

    init(preferences: StatusIntervalPreferences, refresh: @escaping () -> Void) {
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
