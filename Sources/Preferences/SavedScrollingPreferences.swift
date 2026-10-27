import Foundation

final class SavedScrollingPreferences: ScrollingPreferences {
    private let defaults: UserDefaults
    private let key = "automaticallySwitchNaturalScrolling"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var automaticallySwitch: Bool {
        get { defaults.object(forKey: key) as? Bool ?? true }
        set { defaults.set(newValue, forKey: key) }
    }
}

