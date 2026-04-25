public struct TerminalListNavigator: Sendable, Codable, Hashable {
    public enum WrapMode: String, Sendable, Codable, Hashable {
        case wrap
        case clamp
    }

    public private(set) var count: Int
    public private(set) var selectedIndex: Int
    public var wrapMode: WrapMode

    public init(
        count: Int,
        selectedIndex: Int = 0,
        wrapMode: WrapMode = .wrap
    ) {
        self.count = max(
            0,
            count
        )
        self.selectedIndex = max(
            0,
            selectedIndex
        )
        self.wrapMode = wrapMode
        normalize()
    }

    public var hasSelection: Bool {
        count > 0
    }

    public var selection: Int? {
        guard hasSelection else {
            return nil
        }

        return selectedIndex
    }

    public mutating func updateCount(
        _ count: Int
    ) {
        self.count = max(
            0,
            count
        )
        normalize()
    }

    public mutating func select(
        _ index: Int
    ) {
        selectedIndex = index
        normalize()
    }

    public mutating func moveUp(
        by step: Int = 1
    ) {
        move(
            by: -max(1, step)
        )
    }

    public mutating func moveDown(
        by step: Int = 1
    ) {
        move(
            by: max(1, step)
        )
    }

    public mutating func move(
        by offset: Int
    ) {
        guard count > 0 else {
            selectedIndex = 0
            return
        }

        selectedIndex += offset
        normalize()
    }

    private mutating func normalize() {
        guard count > 0 else {
            selectedIndex = 0
            return
        }

        switch wrapMode {
        case .wrap:
            selectedIndex %= count

            if selectedIndex < 0 {
                selectedIndex += count
            }

        case .clamp:
            selectedIndex = min(
                max(
                    selectedIndex,
                    0
                ),
                count - 1
            )
        }
    }
}

public struct TerminalSelectionSet<ID: Hashable & Sendable>: Sendable {
    public private(set) var selected: Set<ID>

    public init(
        selected: Set<ID> = []
    ) {
        self.selected = selected
    }

    public var isEmpty: Bool {
        selected.isEmpty
    }

    public var count: Int {
        selected.count
    }

    public func contains(
        _ id: ID
    ) -> Bool {
        selected.contains(
            id
        )
    }

    public mutating func select(
        _ id: ID
    ) {
        selected.insert(
            id
        )
    }

    public mutating func deselect(
        _ id: ID
    ) {
        selected.remove(
            id
        )
    }

    @discardableResult
    public mutating func toggle(
        _ id: ID
    ) -> Bool {
        if selected.contains(id) {
            selected.remove(
                id
            )
            return false
        }

        selected.insert(
            id
        )
        return true
    }

    public mutating func selectAll<S: Sequence>(
        _ ids: S
    ) where S.Element == ID {
        for id in ids {
            selected.insert(
                id
            )
        }
    }

    public mutating func clear() {
        selected.removeAll()
    }
}
