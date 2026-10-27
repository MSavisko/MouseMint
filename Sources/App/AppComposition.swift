import AppKit

/// The only place that assembles concrete production dependencies.
enum AppComposition {
    static func commands() -> CommandRunner {
        CommandRunner(readMouse: { try LegacyMouseReader().read() },
            readScrolling: { SystemNaturalScrolling().read() },
            migrate: { PreferencesMigration.migrate() }, runGUI: runGUI)
    }
    private static func runGUI(inspection: Bool, settings: Bool) -> Int32 {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let polling = PollingSchedulerAdapter()
        let coordinator = AppCoordinator(reader: LegacyMouseReader(), executor: SerialRefreshExecutor(),
            scheduler: polling, scrolling: AutomaticNaturalScrolling(), readOnly: inspection)
        let delegate = NativeAppDelegate(coordinator: coordinator, polling: polling, inspection: inspection, showSettings: settings)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
        return 0
    }
}
