import Foundation

final class StatusPollingPreferences: StatusIntervalPreferences {
    private let defaults: UserDefaults
    private let key = "statusCheckIntervalSeconds"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var seconds: Int {
        get { StatusInterval.validated(defaults.integer(forKey: key)) }
        set { defaults.set(StatusInterval.validated(newValue), forKey: key) }
    }
}

