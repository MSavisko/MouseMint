import Foundation

enum PreferencesMigration {
    private static let marker = "didMigrateKeychronChargePreferences"

    /// Import only the app's two settings, once, without replacing MouseMint choices.
    static func migrate(defaults: UserDefaults = .standard,
                        domain: String = "io.github.msavisko.mousemint",
                        legacyDomain: String = "local.keychroncharge") {
        let current = defaults.persistentDomain(forName: domain) ?? [:]
        guard current[marker] as? Bool != true else { return }
        let legacy = defaults.persistentDomain(forName: legacyDomain) ?? [:]
        let scrollingKey = "automaticallySwitchNaturalScrolling"
        let intervalKey = "statusCheckIntervalSeconds"
        if current[scrollingKey] == nil, let value = legacy[scrollingKey] as? Bool {
            defaults.set(value, forKey: scrollingKey)
        }
        if current[intervalKey] == nil, let value = legacy[intervalKey] as? Int,
           StatusInterval.seconds.contains(value) {
            defaults.set(value, forKey: intervalKey)
        }
        defaults.set(true, forKey: marker)
    }
}
