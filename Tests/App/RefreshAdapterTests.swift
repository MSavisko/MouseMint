import XCTest

final class RefreshAdapterTests: XCTestCase {
    func testSerialExecutorRunsWorkOffMainAndDeliversOnMain() {
        let delivered = expectation(description: "Delivered on main")
        SerialRefreshExecutor().execute({
            XCTAssertFalse(Thread.isMainThread)
            return ReadObservation(result: .success(testReading()), connection: .connected)
        }, completion: { _ in
            XCTAssertTrue(Thread.isMainThread)
            delivered.fulfill()
        })
        wait(for: [delivered], timeout: 2)
    }

    func testSchedulerLifecycleDoesNotStartOrRestartAStoppedTimer() {
        let domain = "io.github.msavisko.mousemint.scheduler.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let scheduler = PollingSchedulerAdapter(preferences: StatusPollingPreferences(defaults: defaults))
        XCTAssertNil(scheduler.timer)
        scheduler.setSeconds(2)
        XCTAssertNil(scheduler.timer)
        scheduler.start({})
        let old = scheduler.timer!
        XCTAssertEqual(old.timeInterval, 2)
        scheduler.setSeconds(10)
        XCTAssertFalse(old.isValid)
        XCTAssertEqual(scheduler.timer?.timeInterval, 10)
        scheduler.stop()
        XCTAssertNil(scheduler.timer)
        scheduler.setSeconds(3)
        XCTAssertNil(scheduler.timer)
        XCTAssertEqual(scheduler.seconds, 3)
    }
}
