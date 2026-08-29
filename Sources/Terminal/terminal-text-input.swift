public enum TerminalTextInputEvent:
    Sendable,
    Codable,
    Hashable
{
    case changed
    case submitRequested
    case cancelRequested
}

public struct TerminalTextInput:
    Sendable,
    Codable,
    Hashable
{
    public private(set) var text: String
    public private(set) var cursorOffset: Int

    public init(
        text: String = "",
        cursorOffset: Int? = nil
    ) {
        self.text = text
        self.cursorOffset = min(
            max(
                0,
                cursorOffset ?? text.count
            ),
            text.count
        )
    }

    public var isEmpty: Bool {
        text.isEmpty
    }

    public var isAtStart: Bool {
        cursorOffset == 0
    }

    public var isAtEnd: Bool {
        cursorOffset == text.count
    }

    public mutating func handle(
        _ key: TerminalKey
    ) -> TerminalTextInputEvent? {
        switch key {
        case .char(let value):
            return insert(
                value
            )
                ? .changed
                : nil

        case .space:
            _ = insert(
                " "
            )
            return .changed

        case .backspace,
             .control("H"):
            return deleteBackward()
                ? .changed
                : nil

        case .delete:
            return deleteForward()
                ? .changed
                : nil

        case .left,
             .control("B"):
            return moveLeft()
                ? .changed
                : nil

        case .right,
             .control("F"):
            return moveRight()
                ? .changed
                : nil

        case .home,
             .control("A"):
            return moveToStart()
                ? .changed
                : nil

        case .end,
             .control("E"):
            return moveToEnd()
                ? .changed
                : nil

        case .enter:
            return .submitRequested

        case .escape:
            return .cancelRequested

        default:
            return nil
        }
    }

    public mutating func replace(
        with text: String,
        cursorOffset: Int? = nil
    ) {
        self.text = text
        self.cursorOffset = min(
            max(
                0,
                cursorOffset ?? text.count
            ),
            text.count
        )
    }

    @discardableResult
    public mutating func insert(
        _ value: String
    ) -> Bool {
        guard !value.isEmpty else {
            return false
        }

        let insertionIndex = index(
            at: cursorOffset
        )

        text.insert(
            contentsOf: value,
            at: insertionIndex
        )

        cursorOffset += value.count
        return true
    }

    @discardableResult
    public mutating func deleteBackward() -> Bool {
        guard cursorOffset > 0 else {
            return false
        }

        let start = index(
            at: cursorOffset - 1
        )
        let end = index(
            at: cursorOffset
        )

        text.removeSubrange(
            start..<end
        )

        cursorOffset -= 1
        return true
    }

    @discardableResult
    public mutating func deleteForward() -> Bool {
        guard cursorOffset < text.count else {
            return false
        }

        let start = index(
            at: cursorOffset
        )
        let end = index(
            at: cursorOffset + 1
        )

        text.removeSubrange(
            start..<end
        )

        return true
    }

    @discardableResult
    public mutating func moveLeft(
        by amount: Int = 1
    ) -> Bool {
        let previous = cursorOffset

        cursorOffset = max(
            0,
            cursorOffset - max(
                1,
                amount
            )
        )

        return cursorOffset != previous
    }

    @discardableResult
    public mutating func moveRight(
        by amount: Int = 1
    ) -> Bool {
        let previous = cursorOffset

        cursorOffset = min(
            text.count,
            cursorOffset + max(
                1,
                amount
            )
        )

        return cursorOffset != previous
    }

    @discardableResult
    public mutating func moveToStart() -> Bool {
        let previous = cursorOffset
        cursorOffset = 0
        return cursorOffset != previous
    }

    @discardableResult
    public mutating func moveToEnd() -> Bool {
        let previous = cursorOffset
        cursorOffset = text.count
        return cursorOffset != previous
    }

    public mutating func clear() {
        text = ""
        cursorOffset = 0
    }

    private func index(
        at offset: Int
    ) -> String.Index {
        text.index(
            text.startIndex,
            offsetBy: min(
                max(
                    0,
                    offset
                ),
                text.count
            )
        )
    }
}
