import Sparkle

/// Constructed only for a normal GUI launch; diagnostics never start Sparkle.
final class SparkleUpdateBackend: UpdateBackend {
    private let controller = SPUStandardUpdaterController(startingUpdater: false,
        updaterDelegate: nil, userDriverDelegate: nil)
    var canCheck: Bool { controller.updater.canCheckForUpdates }
    func start() { controller.startUpdater() }
    func check() { controller.checkForUpdates(nil) }
}
