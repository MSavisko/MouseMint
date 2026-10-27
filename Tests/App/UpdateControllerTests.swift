import XCTest

private final class FakeUpdates: UpdateBackend {
    var canCheck = false
    var starts = 0
    var checks = 0
    func start() { starts += 1 }
    func check() { checks += 1 }
}

final class UpdateControllerTests: XCTestCase {
    func testReadOnlyInspectionNeverConstructsOrStartsTheUpdater() {
        var constructions = 0
        let controller = UpdateController(readOnly: true, makeBackend: { constructions += 1; return FakeUpdates() })
        controller.start(); controller.check()
        XCTAssertEqual(constructions, 0)
        XCTAssertFalse(controller.canCheck)
    }
    func testNormalStartupIsLazyAndStartsExactlyOnce() {
        let backend = FakeUpdates(); var constructions = 0
        let controller = UpdateController(readOnly: false, makeBackend: { constructions += 1; return backend })
        controller.check()
        XCTAssertEqual(constructions, 0)
        controller.start(); controller.start()
        XCTAssertEqual(constructions, 1)
        XCTAssertEqual(backend.starts, 1)
    }
    func testChecksUseTheBackendsCurrentAvailability() {
        let backend = FakeUpdates()
        let controller = UpdateController(readOnly: false, makeBackend: { backend })
        controller.start(); controller.check()
        XCTAssertEqual(backend.checks, 0)
        backend.canCheck = true
        XCTAssertTrue(controller.canCheck)
        controller.check()
        XCTAssertEqual(backend.checks, 1)
        backend.canCheck = false
        XCTAssertFalse(controller.canCheck)
        controller.check()
        XCTAssertEqual(backend.checks, 1)
    }
}
