public extension Terminal {
    static let io = IO()

    struct IO: Sendable {
        public let stdin = StandardInput()

        public init() {}
    }
}

public extension Terminal.IO {
    struct StandardInput: Sendable {
        public enum Source:
            Sendable,
            Hashable
        {
            case terminal
        }

        public init() {}
    }
}
