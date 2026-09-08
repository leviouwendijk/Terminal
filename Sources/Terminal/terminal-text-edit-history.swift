public struct TerminalTextEditHistory:
    Sendable,
    Hashable
{
    public private(set) var limit: Int

    private var undoStack: [TerminalTextBuffer]
    private var redoStack: [TerminalTextBuffer]
    private var pending: TerminalTextBuffer?

    public init(
        limit: Int = 100
    ) {
        self.limit = max(
            1,
            limit
        )
        self.undoStack = []
        self.redoStack = []
        self.pending = nil
    }

    public var canUndo: Bool {
        !undoStack.isEmpty
    }

    public var canRedo: Bool {
        !redoStack.isEmpty
    }

    public var undoDepth: Int {
        undoStack.count
    }

    public var redoDepth: Int {
        redoStack.count
    }

    public var hasPendingTransaction: Bool {
        pending != nil
    }

    public mutating func reset() {
        undoStack.removeAll()
        redoStack.removeAll()
        pending = nil
    }

    public mutating func begin(
        with buffer: TerminalTextBuffer
    ) {
        guard pending == nil else {
            return
        }

        pending = buffer
    }

    @discardableResult
    public mutating func commit(
        current: TerminalTextBuffer
    ) -> Bool {
        guard let before = pending else {
            return false
        }

        pending = nil

        guard before.text != current.text else {
            return false
        }

        undoStack.append(
            before
        )
        undoStack = Array(
            undoStack.suffix(
                limit
            )
        )
        redoStack.removeAll()
        return true
    }

    public mutating func record(
        before: TerminalTextBuffer,
        after: TerminalTextBuffer
    ) {
        guard before.text != after.text else {
            return
        }

        pending = nil
        undoStack.append(
            before
        )
        undoStack = Array(
            undoStack.suffix(
                limit
            )
        )
        redoStack.removeAll()
    }

    public mutating func undo(
        current: TerminalTextBuffer
    ) -> TerminalTextBuffer? {
        if pending != nil {
            _ = commit(
                current: current
            )
        }

        guard let restored = undoStack.popLast() else {
            return nil
        }

        redoStack.append(
            current
        )
        redoStack = Array(
            redoStack.suffix(
                limit
            )
        )
        return restored
    }

    public mutating func redo(
        current: TerminalTextBuffer
    ) -> TerminalTextBuffer? {
        guard pending == nil,
              let restored = redoStack.popLast() else {
            return nil
        }

        undoStack.append(
            current
        )
        undoStack = Array(
            undoStack.suffix(
                limit
            )
        )
        return restored
    }
}
