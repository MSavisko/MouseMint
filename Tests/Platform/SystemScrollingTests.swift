import XCTest

final class SystemScrollingTests: XCTestCase {
    func testReadUsesInjectedValuesWithoutWritingAndClosesOnRelease() {
        var writes = 0, closes = 0
        var system: SystemNaturalScrolling? = SystemNaturalScrolling(operations: .init(
            readPreference: { false }, readLive: { true }, savePreference: { _ in writes += 1; return true },
            applyLive: { _ in writes += 1 }, close: { closes += 1 }))
        XCTAssertEqual(system!.read(), .init(preference: false, live: true))
        XCTAssertEqual(writes, 0)
        system = nil
        XCTAssertEqual(closes, 1)
    }
    func testMissingEitherSymbolRejectsBeforeSaving() {
        for missingGetter in [true, false] {
            var saves = 0, applies = 0
            let getter: (() -> Bool)? = missingGetter ? nil : { true }
            let setter: ((Bool) -> Void)? = missingGetter ? { _ in applies += 1 } : nil
            let system = SystemNaturalScrolling(operations: .init(readPreference: { true }, readLive: getter,
                savePreference: { _ in saves += 1; return true }, applyLive: setter))
            XCTAssertThrowsError(try system.setEnabled(false)) { XCTAssertEqual($0 as? NaturalScrollingError, .unavailable) }
            XCTAssertEqual(saves, 0); XCTAssertEqual(applies, 0)
        }
    }
    func testSaveFailureNeverCallsNativeSetter() {
        var applies = 0
        let system = SystemNaturalScrolling(operations: .init(readPreference: { true }, readLive: { true },
            savePreference: { _ in false }, applyLive: { _ in applies += 1 }))
        XCTAssertThrowsError(try system.setEnabled(false)) { XCTAssertEqual($0 as? NaturalScrollingError, .saveFailed) }
        XCTAssertEqual(applies, 0)
    }
    func testNativeApplyMismatchIsReportedAndSuccessVerifiesBothValues() throws {
        var saved = true, live = true
        var operations = NaturalScrollingOperations(readPreference: { saved }, readLive: { live },
            savePreference: { saved = $0; return true }, applyLive: { _ in })
        let failing = SystemNaturalScrolling(operations: operations)
        XCTAssertThrowsError(try failing.setEnabled(false)) { XCTAssertEqual($0 as? NaturalScrollingError, .applyFailed) }
        XCTAssertFalse(saved); XCTAssertTrue(live)
        operations.applyLive = { live = $0 }
        let working = SystemNaturalScrolling(operations: operations)
        try working.setEnabled(false)
        XCTAssertEqual(working.read(), .init(preference: false, live: false))
    }
    func testMigrationPreservesExistingAndLegacyUnrelatedValues() {
        let name = "io.github.msavisko.mousemint.migration.\(UUID())"
        let legacyName = name + ".legacy"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name); defaults.removePersistentDomain(forName: legacyName) }
        let legacy: [String: Any] = ["unrelated": "old", "automaticallySwitchNaturalScrolling": false, "statusCheckIntervalSeconds": 2]
        defaults.setPersistentDomain(legacy, forName: legacyName)
        defaults.set("current", forKey: "unrelated")
        PreferencesMigration.migrate(defaults: defaults, domain: name, legacyDomain: legacyName)
        XCTAssertEqual(defaults.string(forKey: "unrelated"), "current")
        XCTAssertEqual(defaults.persistentDomain(forName: legacyName)! as NSDictionary, legacy as NSDictionary)
        XCTAssertEqual(defaults.bool(forKey: "didMigrateKeychronChargePreferences"), true)
        XCTAssertEqual(defaults.integer(forKey: "statusCheckIntervalSeconds"), 2)
    }
}
