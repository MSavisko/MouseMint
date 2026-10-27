protocol UpdateBackend: AnyObject {
    var canCheck: Bool { get }
    func start()
    func check()
}

final class UpdateController {
    private let readOnly: Bool
    private let makeBackend: () -> UpdateBackend
    private var backend: UpdateBackend?
    init(readOnly: Bool, makeBackend: @escaping () -> UpdateBackend) {
        self.readOnly = readOnly; self.makeBackend = makeBackend
    }
    var canCheck: Bool { backend?.canCheck ?? false }
    func start() {
        guard !readOnly, backend == nil else { return }
        let backend = makeBackend()
        self.backend = backend
        backend.start()
    }
    func check() {
        guard canCheck else { return }
        backend?.check()
    }
}
