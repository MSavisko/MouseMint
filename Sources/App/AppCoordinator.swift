import Foundation

protocol MouseStatusReading {
    var deviceName: String { get }
    func read() throws -> MouseReading
    func hasDirectConnection() -> Bool
}
struct ReadObservation {
    let result: Result<MouseReading, Error>
    let connection: MouseConnectionState
}
protocol RefreshExecuting {
    func execute(_ work: @escaping () -> ReadObservation, completion: @escaping (ReadObservation) -> Void)
}
protocol RefreshScheduling: AnyObject {
    var seconds: Int { get }
    func start(_ refresh: @escaping () -> Void)
    func setSeconds(_ value: Int)
    func stop()
}

final class AppCoordinator {
    private let reader: MouseStatusReading
    private let executor: RefreshExecuting
    private let scheduler: RefreshScheduling
    private let scrolling: AutomaticNaturalScrolling
    private let readOnly: Bool
    private(set) var snapshot: AppSnapshot
    var onChange: ((AppSnapshot) -> Void)?

    init(reader: MouseStatusReading, executor: RefreshExecuting, scheduler: RefreshScheduling,
         scrolling: AutomaticNaturalScrolling, readOnly: Bool = false) {
        self.reader = reader; self.executor = executor; self.scheduler = scheduler
        self.scrolling = scrolling; self.readOnly = readOnly
        snapshot = AppSnapshot(interval: scheduler.seconds, scrolling: ScrollingSnapshot(scrolling))
        snapshot.configuredDeviceName = reader.deviceName
    }
    private var running = false
    private var inFlight = false
    private var generation = 0

    func start() {
        precondition(Thread.isMainThread)
        guard !running else { return }
        running = true
        refresh()
        scheduler.start { [weak self] in self?.refresh() }
    }
    func stop() {
        precondition(Thread.isMainThread)
        guard running else { return }
        running = false
        generation += 1
        scheduler.stop()
        snapshot.refreshing = false
        publish()
    }
    func refresh() {
        precondition(Thread.isMainThread)
        guard running, !inFlight else { return }
        inFlight = true
        let token = generation
        snapshot.refreshing = true
        publish()
        executor.execute({ [reader] in
            let result = Result { try reader.read() }
            let connection: MouseConnectionState
            switch result {
            case .success: connection = .connected
            case .failure(let error): connection = (error as? MouseReadError)?.scrollingConnection(directMousePresent: reader.hasDirectConnection()) ?? .unknown
            }
            return ReadObservation(result: result, connection: connection)
        }, completion: { [weak self] observation in
            guard let self else { return }
            precondition(Thread.isMainThread)
            self.inFlight = false
            guard self.running, token == self.generation else {
                if self.running { self.refresh() }
                return
            }
            self.snapshot.refreshing = false
            self.snapshot.connection = observation.connection
            switch observation.result {
            case .success(let reading): self.snapshot.reading = reading; self.snapshot.failure = nil
            case .failure(let error): self.snapshot.reading = nil; self.snapshot.failure = error
            }
            if self.readOnly { self.scrolling.refreshStatus() }
            else { self.scrolling.update(connection: observation.connection) }
            self.publish()
        })
    }
    func setAutomatic(_ value: Bool) {
        precondition(Thread.isMainThread)
        guard !readOnly else { return }
        scrolling.setAutomatic(value)
        publish()
        if value { refresh() }
    }
    func setNaturalScrolling(_ value: Bool) {
        precondition(Thread.isMainThread)
        guard !readOnly else { return }
        scrolling.setManual(value)
        publish()
    }
    func setInterval(_ value: Int) {
        precondition(Thread.isMainThread)
        guard !readOnly else { return }
        scheduler.setSeconds(value)
        snapshot.interval = scheduler.seconds
        publish()
    }
    func inspectScrolling() { scrolling.refreshStatus(); publish() }
    private func publish() {
        snapshot.scrolling = ScrollingSnapshot(scrolling)
        onChange?(snapshot)
    }
}
