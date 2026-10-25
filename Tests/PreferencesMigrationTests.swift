import Foundation

@main struct PreferencesMigrationTests {
    static func main() {
        let scrolling = "automaticallySwitchNaturalScrolling"
        let interval = "statusCheckIntervalSeconds"

        func check(legacy: [String: Any], current: [String: Any] = [:],
                   expectedScrolling: Bool, expectedInterval: Int) {
            let domain = "io.github.msavisko.mousemint.tests.\(UUID().uuidString)"
            let legacyDomain = domain + ".legacy"
            let defaults = UserDefaults(suiteName: domain)!
            defaults.setPersistentDomain(legacy, forName: legacyDomain)
            defaults.setPersistentDomain(current, forName: domain)
            defer {
                defaults.removePersistentDomain(forName: domain)
                defaults.removePersistentDomain(forName: legacyDomain)
                defaults.synchronize()
            }
            PreferencesMigration.migrate(defaults: defaults, domain: domain, legacyDomain: legacyDomain)
            precondition(SavedScrollingPreferences(defaults: defaults).automaticallySwitch == expectedScrolling)
            precondition(StatusPollingPreferences(defaults: defaults).seconds == expectedInterval)
            precondition((defaults.persistentDomain(forName: legacyDomain)?.count ?? 0) == legacy.count)
            precondition(defaults.object(forKey: "unrelated") == nil)

            // Later launches must retain MouseMint changes even if old settings change.
            defaults.set(!expectedScrolling, forKey: scrolling)
            defaults.set(8, forKey: interval)
            PreferencesMigration.migrate(defaults: defaults, domain: domain, legacyDomain: legacyDomain)
            precondition(SavedScrollingPreferences(defaults: defaults).automaticallySwitch == !expectedScrolling)
            precondition(StatusPollingPreferences(defaults: defaults).seconds == 8)
        }

        check(legacy: [scrolling: false, interval: 10, "unrelated": "ignore"], expectedScrolling: false, expectedInterval: 10)
        check(legacy: [scrolling: true, interval: 2], expectedScrolling: true, expectedInterval: 2)
        check(legacy: [scrolling: true, interval: 2], current: [scrolling: false, interval: 3], expectedScrolling: false, expectedInterval: 3)
        check(legacy: [scrolling: false, interval: 10], current: [interval: 8], expectedScrolling: false, expectedInterval: 8)
        check(legacy: [:], expectedScrolling: true, expectedInterval: 5)
        check(legacy: [scrolling: "invalid", interval: 4], expectedScrolling: true, expectedInterval: 5)
        print("Preference migration preserves choices, imports valid settings once, and leaves legacy data intact.")
    }
}
