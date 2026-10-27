import AppKit
import XCTest

func testSnapshot() -> AppSnapshot {
    let backend = TestScrollingBackend()
    backend.state = .init(preference: false, live: false)
    let scrolling = AutomaticNaturalScrolling(backend: backend, preferences: TestScrollingPreferences())
    var state = AppSnapshot(interval: 5, scrolling: ScrollingSnapshot(scrolling))
    state.configuredDeviceName = "Keychron M3"
    return state
}

final class PresentationTests: XCTestCase {
    override func setUp() { _ = NSApplication.shared }
    func testMenuStatesAndExactConnectedRows() {
        let button = NSButton()
        let view = StatusMenu(button: button, settings: {}, quit: {}, formatDate: { _ in "fixed" })
        var state = testSnapshot()
        view.render(state)
        XCTAssertEqual(button.title, " Checking…")
        state.reading = testReading()
        view.render(state)
        XCTAssertEqual(button.title, " 72%")
        XCTAssertEqual(button.image?.accessibilityDescription, "USB cable")
        XCTAssertEqual(view.menu.items.filter { !$0.isSeparatorItem }.map(\.title), [
            "Keychron M3", "Connection: USB cable", "Battery: 72%", "Status: On battery", "Updated: fixed",
            "Natural Scrolling: Off (automatic)", "Settings…", "Quit MouseMint"])
        state.reading = testReading(.bluetooth, battery: nil)
        view.render(state)
        XCTAssertEqual(button.title, " —")
        XCTAssertTrue(view.menu.items.contains { $0.title == "Battery: Waiting for macOS" })
        state.reading = nil; state.failure = MouseReadError.receiverDisconnected
        view.render(state)
        XCTAssertEqual(button.title, " Not connected")
        XCTAssertEqual(button.image?.accessibilityDescription, "Mouse not connected")
        state.failure = MouseReadError.receiverUnavailable
        view.render(state)
        XCTAssertEqual(button.title, " Read error")
        XCTAssertEqual(button.image?.accessibilityDescription, "Mouse status unavailable")
    }

    func testMenuUsesTheSelectedDriversName() {
        var state = testSnapshot()
        var reading = testReading()
        reading.deviceName = "Example Mouse"
        state.reading = reading
        let button = NSButton()
        let view = StatusMenu(button: button, settings: {}, quit: {})
        view.render(state)
        XCTAssertEqual(view.menu.items.first?.title, "Example Mouse")
        XCTAssertTrue(button.toolTip?.hasPrefix("Example Mouse:") == true)
    }

    func testNativeMenuActionsUseInjectedCallbacks() throws {
        var settings = 0, quits = 0
        let view = StatusMenu(button: NSButton(), settings: { settings += 1 }, quit: { quits += 1 })
        view.render(testSnapshot())
        let row = try XCTUnwrap(view.menu.items.first { $0.title == "Settings…" })
        NSApp.sendAction(try XCTUnwrap(row.action), to: row.target, from: row)
        let quit = try XCTUnwrap(view.menu.items.last)
        NSApp.sendAction(try XCTUnwrap(quit.action), to: quit.target, from: quit)
        XCTAssertEqual(settings, 1); XCTAssertEqual(quits, 1)
    }

    func testFrozenDiagnosticsAndUnavailableBluetoothSource() {
        var state = testSnapshot(); state.reading = testReading()
        XCTAssertEqual(DiagnosticReport.make(state, version: "test-version", system: "test-os"), """
        MouseMint — test-version
        macOS: test-os
        Status check interval: 5 seconds
        Connection: USB cable
        Product ID: D033
        Battery: 72%
        Power state: 0 (On battery)
        Read at: 1970-01-01T00:00:00Z
        Report:\u{20}
        Natural Scrolling: Off (automatic)
        Automatic switching: On
        Natural Scrolling saved: Off
        Natural Scrolling live: Off

        """)
        state.reading = testReading(.bluetooth, battery: nil)
        let report = DiagnosticReport.make(state, version: "v", system: "os")
        XCTAssertTrue(report.contains("Battery unavailable\n"))
        XCTAssertTrue(report.contains("Source: macOS accessory battery service"))
        XCTAssertFalse(report.contains("Report:"))
    }

    func testSettingsConsumesSnapshotAndActionsReachCoordinatorWithoutRenderWrites() {
        let backend = TestScrollingBackend()
        let executor = ManualRefreshExecutor()
        let coordinator = AppCoordinator(reader: TestMouseReader(), executor: executor,
            scheduler: ManualRefreshScheduler(), scrolling: AutomaticNaturalScrolling(backend: backend, preferences: TestScrollingPreferences()))
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let settings = SettingsWindow(automaticChanged: coordinator.setAutomatic,
            naturalChanged: coordinator.setNaturalScrolling, intervalChanged: coordinator.setInterval,
            refreshRequested: coordinator.refresh, diagnostics: { "test" }, pasteboard: pasteboard)
        coordinator.onChange = { state in settings.update(state: state.scrolling, refreshing: state.refreshing, statusInterval: state.interval) }
        settings.update(state: coordinator.snapshot.scrolling)
        XCTAssertEqual(settings.automaticSwitch.state, .on)
        XCTAssertEqual(backend.writes, [])
        settings.selectPane(.naturalScrolling)
        settings.automaticSwitch.state = .off
        NSApp.sendAction(settings.automaticSwitch.action!, to: settings.automaticSwitch.target, from: settings.automaticSwitch)
        XCTAssertFalse(coordinator.snapshot.scrolling.automatic)
        XCTAssertTrue(settings.naturalSwitch.isEnabled)
        settings.naturalSwitch.state = .off
        NSApp.sendAction(settings.naturalSwitch.action!, to: settings.naturalSwitch.target, from: settings.naturalSwitch)
        XCTAssertEqual(backend.writes, [false])
    }
}
