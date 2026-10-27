import AppKit

/// The only place that assembles concrete production dependencies.
enum AppComposition {
    static func commands() -> CommandRunner {
        CommandRunner(readMouse: { try reader().read() },
            readScrolling: { SystemNaturalScrolling().read() },
            migrate: { PreferencesMigration.migrate() }, runGUI: runGUI)
    }
    private static func reader() -> DeviceStatusService {
        let access = SystemHIDAccess()
        let timing = DeviceReadTiming(now: { ProcessInfo.processInfo.systemUptime },
            sleep: { Thread.sleep(forTimeInterval: $0) }, date: { Date() })
        return DeviceStatusService(access: access, drivers: [KeychronM3Driver(access: access,
            accessory: SystemAccessoryBatterySource(), timing: timing)])
    }
    private static func runGUI(inspection: Bool, settings: Bool) -> Int32 {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let polling = PollingSchedulerAdapter(preferences: StatusPollingPreferences())
        let coordinator = AppCoordinator(reader: reader(), executor: SerialRefreshExecutor(),
            scheduler: polling, scrolling: AutomaticNaturalScrolling(backend: SystemNaturalScrolling(), preferences: SavedScrollingPreferences()), readOnly: inspection)
        let delegate = NativeAppDelegate(coordinator: coordinator, polling: polling, inspection: inspection, showSettings: settings,
            updates: UpdateController(readOnly: inspection, makeBackend: { SparkleUpdateBackend() }))
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
        return 0
    }
}
