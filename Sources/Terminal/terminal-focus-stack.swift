public struct TerminalFocusStack<ID: Hashable & Sendable>:
    Sendable,
    Hashable
{
    public private(set) var current: ID

    private var history: [ID]

    public init(
        _ current: ID
    ) {
        self.current = current
        self.history = []
    }

    public var depth: Int {
        history.count
    }

    public mutating func replace(
        _ id: ID
    ) {
        current = id
    }

    public mutating func push(
        _ id: ID
    ) {
        history.append(
            current
        )
        current = id
    }

    @discardableResult
    public mutating func pop() -> ID {
        guard let previous = history.popLast() else {
            return current
        }

        current = previous
        return current
    }

    public mutating func reset(
        to id: ID
    ) {
        history.removeAll(
            keepingCapacity: true
        )
        current = id
    }
}
