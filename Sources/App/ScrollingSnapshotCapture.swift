extension ScrollingSnapshot {
    init(_ scrolling: AutomaticNaturalScrolling) {
        self.init(state: scrolling.state, automatic: scrolling.isAutomatic, failure: scrolling.failure)
    }
}
