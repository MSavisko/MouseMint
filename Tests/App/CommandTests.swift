import XCTest

final class CommandTests: XCTestCase {
    func testReadOnlyCommandsDoNotRunMigrationOrGUI() throws {
        var calls: [String] = []
        let runner = CommandRunner(readMouse: { calls.append("mouse"); return testReading() },
            readScrolling: { calls.append("scroll"); return .init(preference: nil, live: false) },
            migrate: { calls.append("migrate") }, runGUI: { _, _ in calls.append("gui"); return 0 })
        let scroll = runner.run(["--read-json", "--scroll-status"])
        XCTAssertEqual(calls, ["scroll"])
        XCTAssertEqual(scroll.status, 0)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: Data(scroll.stdout.utf8)) as? NSDictionary, ["live": false] as NSDictionary)
        calls = []
        let mouse = runner.run(["--read-json"])
        XCTAssertEqual(calls, ["mouse"])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(mouse.stdout.utf8)) as? [String: Any])
        XCTAssertEqual(json["mode"] as? String, "cable")
        XCTAssertEqual(json["date"] as? String, "1970-01-01T00:00:00Z")
    }
    func testInspectionSkipsMigrationAndNormalLaunchMigratesBeforeGUI() {
        var calls: [String] = []
        let runner = CommandRunner(readMouse: { testReading() }, readScrolling: { .init(preference: nil, live: nil) },
            migrate: { calls.append("migrate") }, runGUI: { inspect, settings in calls.append("gui:\(inspect):\(settings)"); return 0 })
        _ = runner.run(["--check-ui", "--settings"])
        XCTAssertEqual(calls, ["gui:true:true"])
        calls = []
        _ = runner.run(["--settings"])
        XCTAssertEqual(calls, ["migrate", "gui:false:true"])
    }
    func testReadFailureKeepsErrorAndExitStatus() {
        let runner = CommandRunner(readMouse: { throw MouseReadError.invalid },
            readScrolling: { .init(preference: nil, live: nil) }, migrate: { XCTFail("Unexpected migration") },
            runGUI: { _, _ in XCTFail("Unexpected GUI"); return 0 })
        let output = runner.run(["--read-json"])
        XCTAssertEqual(output.status, 1)
        XCTAssertEqual(output.stdout, "")
        XCTAssertEqual(output.stderr, MouseReadError.invalid.description)
    }
}
