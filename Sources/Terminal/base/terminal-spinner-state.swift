public struct TerminalSpinnerState:
    Sendable,
    Hashable
{
    public static let standardFrames = [
        "⠋",
        "⠙",
        "⠹",
        "⠸",
        "⠼",
        "⠴",
        "⠦",
        "⠧",
        "⠇",
        "⠏",
    ]

    public let frames: [String]
    public private(set) var index: Int

    public init(
        frames: [String] = TerminalSpinnerState.standardFrames,
        index: Int = 0
    ) {
        let resolvedFrames = frames.isEmpty
            ? TerminalSpinnerState.standardFrames
            : frames
        let count = resolvedFrames.count

        self.frames = resolvedFrames
        self.index = ((index % count) + count) % count
    }

    public var currentFrame: String {
        frames[index]
    }

    @discardableResult
    public mutating func advance() -> String {
        index = (index + 1) % frames.count
        return currentFrame
    }

    public mutating func reset() {
        index = 0
    }
}
