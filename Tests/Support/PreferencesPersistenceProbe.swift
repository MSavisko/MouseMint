import Foundation

/// A separate executable confirms settings survive beyond the test process.
@main struct PreferencesPersistenceProbe {
    static func main() {
        guard CommandLine.arguments.count == 2,
              let defaults = UserDefaults(suiteName: CommandLine.arguments[1]),
              !SavedScrollingPreferences(defaults: defaults).automaticallySwitch,
              StatusPollingPreferences(defaults: defaults).seconds == 10 else {
            exit(1)
        }
    }
}
