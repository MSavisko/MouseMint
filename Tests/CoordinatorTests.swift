import XCTest
import Foundation

final class TestMouseReader: MouseStatusReading {
    var result: Result<MouseReading, Error> = .success(testReading())
    var direct = false
    var duringRead: (() -> Void)?
    var reads = 0
    func read() throws -> MouseReading { reads += 1; duringRead?(); return try result.get() }
    func hasDirectConnection() -> Bool { direct }
}

func testReading(_ mode: ConnectionMode = .cable, battery: Int? = 72) -> MouseReading {
    MouseReading(date: Date(timeIntervalSince1970: 0),
        status: battery.map { BatteryStatus(percentage: $0, powerState: 0, usbRevision: nil) },
        rawReport: [], mode: mode, productID: mode == .receiver ? 0xD031 : 0xD033)
}

final class ManualRefreshExecutor: RefreshExecuting {
    var pending: [(() -> ReadObservation, (ReadObservation) -> Void)] = []
    func execute(_ work: @escaping () -> ReadObservation, completion: @escaping (ReadObservation) -> Void) {
        pending.append((work, completion))
    }
    func finish() { let item = pending.removeFirst(); item.1(item.0()) }
}

final class ManualRefreshScheduler: RefreshScheduling {
    var seconds = 5
    var callback: (() -> Void)?
    var stops = 0
    func start(_ refresh: @escaping () -> Void) { callback = refresh }
    func setSeconds(_ value: Int) { seconds = StatusInterval.validated(value) }
    func stop() { stops += 1; callback = nil }
}

final class TestScrollingPreferences: ScrollingPreferences { var automaticallySwitch = true }
final class TestScrollingBackend: NaturalScrollingBackend {
    var state = NaturalScrollingState(preference: true, live: true)
    var writes: [Bool] = []
    func read() -> NaturalScrollingState { state }
    func setEnabled(_ value: Bool) { writes.append(value); state = .init(preference: value, live: value) }
}

final class CoordinatorTests: XCTestCase {
    let reader = TestMouseReader()
    let executor = ManualRefreshExecutor()
    let scheduler = ManualRefreshScheduler()
    let backend = TestScrollingBackend()
    let preferences = TestScrollingPreferences()
    func make(readOnly: Bool = false) -> AppCoordinator {
        AppCoordinator(reader: reader, executor: executor, scheduler: scheduler,
            scrolling: AutomaticNaturalScrolling(backend: backend, preferences: preferences), readOnly: readOnly)
    }

    func testStartPublishesCheckingThenSuccessfulReading() {
        let app = make()
        var events = 0
        app.onChange = { _ in XCTAssertTrue(Thread.isMainThread); events += 1 }
        app.start()
        XCTAssertTrue(app.snapshot.refreshing)
        XCTAssertEqual(executor.pending.count, 1)
        executor.finish()
        XCTAssertFalse(app.snapshot.refreshing)
        XCTAssertEqual(app.snapshot.reading?.status?.percentage, 72)
        XCTAssertTrue(app.snapshot.connection == .connected)
        XCTAssertEqual(backend.writes, [false])
        XCTAssertEqual(events, 2)
    }

    func testEveryRefreshTriggerSharesSingleFlight() {
        let app = make(); app.start()
        app.refresh(); scheduler.callback?(); app.refresh()
        XCTAssertEqual(executor.pending.count, 1)
        executor.finish()
        app.refresh()
        XCTAssertEqual(executor.pending.count, 1)
    }

    func testDisconnectClearsBatteryAndUnknownFailureDoesNotChangeScrolling() {
        let app = make(); app.start(); executor.finish()
        reader.result = .failure(MouseReadError.receiverUnavailable)
        app.refresh(); executor.finish()
        XCTAssertNil(app.snapshot.reading)
        XCTAssertTrue(app.snapshot.connection == .unknown)
        XCTAssertFalse(app.snapshot.disconnected)
        XCTAssertEqual(backend.writes, [false])
        reader.result = .failure(MouseReadError.receiverDisconnected)
        app.refresh(); executor.finish()
        XCTAssertTrue(app.snapshot.disconnected)
        XCTAssertNil(app.snapshot.reading)
        XCTAssertEqual(backend.writes, [false, true])
    }

    func testConnectedBluetoothCanHaveNoBattery() {
        reader.result = .success(testReading(.bluetooth, battery: nil))
        let app = make(); app.start(); executor.finish()
        XCTAssertTrue(app.snapshot.connection == .connected)
        XCTAssertNotNil(app.snapshot.reading)
        XCTAssertNil(app.snapshot.reading?.status)
        XCTAssertNil(app.snapshot.failure)
    }

    func testDisablingAutomationWhileReadingPreventsLateWrite() {
        let app = make(); app.start()
        app.setAutomatic(false)
        executor.finish()
        XCTAssertEqual(backend.writes, [])
        XCTAssertFalse(app.snapshot.scrolling.automatic)
    }

    func testDirectConnectionAppearingDuringFailureWinsForScrolling() {
        reader.result = .failure(MouseReadError.disconnected)
        reader.duringRead = { self.reader.direct = true }
        let app = make(); app.start(); executor.finish()
        XCTAssertTrue(app.snapshot.connection == .connected)
        XCTAssertEqual(backend.writes, [false])
        XCTAssertTrue(app.snapshot.disconnected) // Preserve the current read-error presentation.
    }

    func testStopIgnoresLateResultsAndDoesNotRestoreScrolling() {
        let app = make(); app.start(); app.stop(); executor.finish()
        XCTAssertNil(app.snapshot.reading)
        XCTAssertFalse(app.snapshot.refreshing)
        XCTAssertEqual(backend.writes, [])
        XCTAssertEqual(scheduler.stops, 1)
        app.refresh()
        XCTAssertTrue(executor.pending.isEmpty)
    }

    func testRestartWaitsForOldReadBeforeStartingAnother() {
        let app = make(); app.start(); app.stop(); app.start()
        XCTAssertEqual(executor.pending.count, 1)
        executor.finish()
        XCTAssertEqual(executor.pending.count, 1)
        executor.finish()
        XCTAssertNotNil(app.snapshot.reading)
        XCTAssertEqual(reader.reads, 2)
    }

    func testReadOnlyRefreshAndActionsNeverMutatePreferencesOrScrolling() {
        let app = make(readOnly: true)
        app.start(); executor.finish()
        app.setAutomatic(false); app.setNaturalScrolling(false); app.setInterval(10)
        XCTAssertEqual(backend.writes, [])
        XCTAssertTrue(preferences.automaticallySwitch)
        XCTAssertEqual(scheduler.seconds, 5)
    }

    func testActionsUpdateTheSameSnapshotAndReenableRequestsReading() {
        let app = make(); app.start(); executor.finish()
        app.setInterval(10)
        XCTAssertEqual(app.snapshot.interval, 10)
        app.setAutomatic(false)
        app.setNaturalScrolling(true)
        XCTAssertEqual(app.snapshot.scrolling.state.live, true)
        app.setAutomatic(true)
        XCTAssertEqual(executor.pending.count, 1)
    }
}
