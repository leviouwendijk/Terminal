public struct TerminalFocusState<ID: Hashable & Sendable>:
    Sendable,
    Hashable
{
    public private(set) var order: [ID]
    public private(set) var focused: ID?

    public init(
        order: [ID],
        focused: ID? = nil
    ) {
        let order = Self.unique(
            order
        )

        self.order = order

        if let focused,
           order.contains(focused) {
            self.focused = focused
        } else {
            self.focused = order.first
        }
    }

    public mutating func updateOrder(
        _ order: [ID]
    ) {
        let previous = focused
        let order = Self.unique(
            order
        )

        self.order = order

        if let previous,
           order.contains(previous) {
            focused = previous
        } else {
            focused = order.first
        }
    }

    @discardableResult
    public mutating func focus(
        _ id: ID
    ) -> Bool {
        guard order.contains(id) else {
            return false
        }

        let changed = focused != id
        focused = id
        return changed
    }

    @discardableResult
    public mutating func moveNext() -> Bool {
        move(
            by: 1
        )
    }

    @discardableResult
    public mutating func movePrevious() -> Bool {
        move(
            by: -1
        )
    }

    @discardableResult
    private mutating func move(
        by offset: Int
    ) -> Bool {
        guard !order.isEmpty else {
            focused = nil
            return false
        }

        let currentIndex = focused
            .flatMap {
                order.firstIndex(
                    of: $0
                )
            }
            ?? 0
        let count = order.count
        let nextIndex = (
            (
                currentIndex + offset
            ) % count
            + count
        ) % count
        let next = order[nextIndex]
        let changed = focused != next

        focused = next
        return changed
    }

    private static func unique(
        _ order: [ID]
    ) -> [ID] {
        var seen: Set<ID> = []

        return order.filter {
            seen.insert($0).inserted
        }
    }
}
