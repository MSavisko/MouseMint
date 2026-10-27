import AppKit
import XCTest

final class UpdateActionsTests: XCTestCase {
    func testMenuUpdateActionAndCurrentAvailability() throws {
        _ = NSApplication.shared
        var checks = 0, available = false
        let menu = StatusMenu(button: NSButton(), settings: {}, quit: {},
            checkForUpdates: { checks += 1 }, canCheckForUpdates: { available })
        menu.render(testSnapshot())
        let row = try XCTUnwrap(menu.menu.items.first { $0.title == "Check for Updates…" })
        menu.menu.update()
        XCTAssertFalse(row.isEnabled)
        available = true
        menu.menu.update()
        XCTAssertTrue(row.isEnabled)
        NSApp.sendAction(try XCTUnwrap(row.action), to: row.target, from: row)
        XCTAssertEqual(checks, 1)
    }
    func testAboutUpdatesUseCallbacksWithoutCheckingDuringRendering() throws {
        _ = NSApplication.shared
        var checks = 0, available = false
        let clipboard = NSPasteboard.withUniqueName()
        defer { clipboard.releaseGlobally() }
        let settings = SettingsWindow(automaticChanged: { _ in }, naturalChanged: { _ in },
            intervalChanged: { _ in }, refreshRequested: {}, diagnostics: { "fixture" }, pasteboard: clipboard,
            checkForUpdates: { checks += 1 }, canCheckForUpdates: { available })
        settings.selectPane(.about)
        settings.update(state: testSnapshot().scrolling)
        XCTAssertEqual(checks, 0)
        XCTAssertNotNil(settings.updateButton.superview)
        XCTAssertFalse(settings.updateButton.isEnabled)
        available = true
        settings.update(state: testSnapshot().scrolling)
        XCTAssertTrue(settings.updateButton.isEnabled)
        NSApp.sendAction(try XCTUnwrap(settings.updateButton.action), to: settings.updateButton.target, from: settings.updateButton)
        XCTAssertEqual(checks, 1)
    }
}
