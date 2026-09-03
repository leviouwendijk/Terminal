public struct TerminalSpinnerControl:
    Sendable,
    Hashable
{
    public var label: String
    public private(set) var state: TerminalSpinnerState

    public init(
        label: String = "",
        state: TerminalSpinnerState = .init()
    ) {
        self.label = label
        self.state = state
    }

    @discardableResult
    public mutating func advance() -> String {
        state.advance()
    }

    public mutating func reset() {
        state.reset()
    }

    public func render() -> String {
        let body = label.isEmpty
            ? state.currentFrame
            : "\(state.currentFrame) \(label)"

        return TerminalStyle.dim.apply(
            body
        )
    }
}
