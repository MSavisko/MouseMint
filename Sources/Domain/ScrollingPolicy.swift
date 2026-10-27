enum ScrollingPolicy {
    static func desiredState(connection: MouseConnectionState, automatic: Bool) -> Bool? {
        guard automatic else { return nil }
        switch connection {
        case .connected: return false
        case .disconnected: return true
        case .unknown: return nil
        }
    }
}
