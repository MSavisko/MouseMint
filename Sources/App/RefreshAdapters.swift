import Foundation

final class SerialRefreshExecutor: RefreshExecuting {
    private let queue = DispatchQueue(label: "io.github.msavisko.mousemint.usb", qos: .utility)
    func execute(_ work: @escaping () -> ReadObservation, completion: @escaping (ReadObservation) -> Void) {
        queue.async {
            let result = work()
            DispatchQueue.main.async { completion(result) }
        }
    }
}

final class PollingSchedulerAdapter: RefreshScheduling {
    private let preferences: StatusIntervalPreferences
    private var polling: StatusPolling?
    var seconds: Int { preferences.seconds }
    var timer: Timer? { polling?.timer }
    init(preferences: StatusIntervalPreferences) { self.preferences = preferences }
    func start(_ refresh: @escaping () -> Void) {
        stop()
        let next = StatusPolling(preferences: preferences, refresh: refresh)
        polling = next
        next.start()
    }
    func setSeconds(_ value: Int) {
        if let polling { polling.setSeconds(value) }
        else { preferences.seconds = value }
    }
    func stop() { polling?.timer?.invalidate(); polling = nil }
    deinit { polling?.timer?.invalidate() }
}
