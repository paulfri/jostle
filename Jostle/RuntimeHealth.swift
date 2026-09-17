enum RuntimeAvailability: Equatable {
    case ready
    case accessibilityRequired
    case eventTapUnavailable
}

enum RuntimeHealthPolicy {
    static func availability(
        accessibilityTrusted: Bool,
        eventTapRequested: Bool,
        eventTapOperational: Bool
    ) -> RuntimeAvailability {
        guard accessibilityTrusted else { return .accessibilityRequired }
        guard !eventTapRequested || eventTapOperational else {
            return .eventTapUnavailable
        }
        return .ready
    }
}
