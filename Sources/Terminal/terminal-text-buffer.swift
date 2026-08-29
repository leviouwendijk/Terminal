import Foundation

public struct TerminalTextPosition:
    Sendable,
    Codable,
    Hashable
{
    public var row: Int
    public var column: Int

    public init(
        row: Int,
        column: Int
    ) {
        self.row = max(
            0,
            row
        )
        self.column = max(
            0,
            column
        )
    }
}

public struct TerminalTextBuffer:
    Sendable,
    Codable,
    Hashable
{
    public private(set) var text: String
    public private(set) var cursorOffset: Int

    private var preferredColumn: Int?

    public init(
        text: String = "",
        cursorOffset: Int? = nil
    ) {
        let text = Self.normalized(
            text
        )

        self.text = text
        self.cursorOffset = min(
            max(
                0,
                cursorOffset ?? text.count
            ),
            text.count
        )
        self.preferredColumn = nil
    }

    public var isEmpty: Bool {
        text.isEmpty
    }

    public var characterCount: Int {
        text.count
    }

    public var lineCount: Int {
        text.reduce(
            1
        ) {
            count,
            character in

            count
                + (character == "\n" ? 1 : 0)
        }
    }

    public var cursorPosition: TerminalTextPosition {
        let characters = Array(
            text
        )
        let cursor = min(
            cursorOffset,
            characters.count
        )
        var row = 0
        var lineStart = 0

        for index in 0..<cursor {
            if characters[index] == "\n" {
                row += 1
                lineStart = index + 1
            }
        }

        return TerminalTextPosition(
            row: row,
            column: cursor - lineStart
        )
    }

    public mutating func replace(
        with text: String,
        cursorOffset: Int? = nil
    ) {
        let text = Self.normalized(
            text
        )

        self.text = text
        self.cursorOffset = min(
            max(
                0,
                cursorOffset ?? text.count
            ),
            text.count
        )
        preferredColumn = nil
    }

    @discardableResult
    public mutating func setCursor(
        offset: Int
    ) -> Bool {
        setCursor(
            offset,
            preservingPreferredColumn: false
        )
    }

    @discardableResult
    public mutating func insert(
        _ value: String
    ) -> Bool {
        let value = Self.normalized(
            value
        )

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
        preferredColumn = nil
        return true
    }

    @discardableResult
    public mutating func insertNewline() -> Bool {
        insert(
            "\n"
        )
    }

    @discardableResult
    public mutating func deleteBackward() -> Bool {
        guard cursorOffset > 0 else {
            return false
        }

        return delete(
            (cursorOffset - 1)..<cursorOffset
        )
    }

    @discardableResult
    public mutating func deleteForward() -> Bool {
        guard cursorOffset < text.count else {
            return false
        }

        return delete(
            cursorOffset..<(cursorOffset + 1)
        )
    }

    @discardableResult
    public mutating func delete(
        _ requestedRange: Range<Int>
    ) -> Bool {
        let range = clamped(
            requestedRange
        )

        guard !range.isEmpty else {
            return false
        }

        let lower = index(
            at: range.lowerBound
        )
        let upper = index(
            at: range.upperBound
        )

        text.removeSubrange(
            lower..<upper
        )
        cursorOffset = range.lowerBound
        preferredColumn = nil
        return true
    }

    @discardableResult
    public mutating func replace(
        _ requestedRange: Range<Int>,
        with replacement: String
    ) -> Bool {
        let range = clamped(
            requestedRange
        )
        let replacement = Self.normalized(
            replacement
        )
        let lower = index(
            at: range.lowerBound
        )
        let upper = index(
            at: range.upperBound
        )

        guard !range.isEmpty
            || !replacement.isEmpty else {
            return false
        }

        text.replaceSubrange(
            lower..<upper,
            with: replacement
        )
        cursorOffset =
            range.lowerBound
            + replacement.count
        preferredColumn = nil
        return true
    }

    public func text(
        in requestedRange: Range<Int>
    ) -> String {
        let range = clamped(
            requestedRange
        )
        let lower = index(
            at: range.lowerBound
        )
        let upper = index(
            at: range.upperBound
        )

        return String(
            text[lower..<upper]
        )
    }

    @discardableResult
    public mutating func moveLeft(
        by amount: Int = 1
    ) -> Bool {
        setCursor(
            cursorOffset - max(0, amount),
            preservingPreferredColumn: false
        )
    }

    @discardableResult
    public mutating func moveRight(
        by amount: Int = 1
    ) -> Bool {
        setCursor(
            cursorOffset + max(0, amount),
            preservingPreferredColumn: false
        )
    }

    @discardableResult
    public mutating func moveUp(
        by amount: Int = 1
    ) -> Bool {
        moveVertically(
            by: -max(0, amount)
        )
    }

    @discardableResult
    public mutating func moveDown(
        by amount: Int = 1
    ) -> Bool {
        moveVertically(
            by: max(0, amount)
        )
    }

    @discardableResult
    public mutating func moveToLineStart() -> Bool {
        setCursor(
            lineStartOffset(
                for: cursorOffset
            ),
            preservingPreferredColumn: false
        )
    }

    @discardableResult
    public mutating func moveToLineEnd() -> Bool {
        setCursor(
            lineEndOffset(
                for: cursorOffset
            ),
            preservingPreferredColumn: false
        )
    }

    @discardableResult
    public mutating func moveToDocumentStart() -> Bool {
        setCursor(
            0,
            preservingPreferredColumn: false
        )
    }

    @discardableResult
    public mutating func moveToDocumentEnd() -> Bool {
        setCursor(
            text.count,
            preservingPreferredColumn: false
        )
    }

    @discardableResult
    public mutating func moveWordBackward() -> Bool {
        let characters = Array(
            text
        )

        guard cursorOffset > 0,
              !characters.isEmpty else {
            return false
        }

        var index = cursorOffset - 1

        while index > 0,
              wordClass(
                characters[index]
              ) == .whitespace
        {
            index -= 1
        }

        let targetClass = wordClass(
            characters[index]
        )

        while index > 0,
              wordClass(
                characters[index - 1]
              ) == targetClass
        {
            index -= 1
        }

        return setCursor(
            index,
            preservingPreferredColumn: false
        )
    }

    @discardableResult
    public mutating func moveWordForward() -> Bool {
        let characters = Array(
            text
        )

        guard cursorOffset < characters.count else {
            return false
        }

        var index = cursorOffset
        let currentClass = wordClass(
            characters[index]
        )

        while index < characters.count,
              wordClass(
                characters[index]
              ) == currentClass
        {
            index += 1
        }

        while index < characters.count,
              wordClass(
                characters[index]
              ) == .whitespace
        {
            index += 1
        }

        return setCursor(
            index,
            preservingPreferredColumn: false
        )
    }

    @discardableResult
    public mutating func moveToWordEnd() -> Bool {
        let characters = Array(
            text
        )

        guard cursorOffset < characters.count else {
            return false
        }

        var index = cursorOffset

        while index < characters.count,
              wordClass(
                characters[index]
              ) == .whitespace
        {
            index += 1
        }

        guard index < characters.count else {
            return setCursor(
                characters.count,
                preservingPreferredColumn: false
            )
        }

        let targetClass = wordClass(
            characters[index]
        )

        while index < characters.count,
              wordClass(
                characters[index]
              ) == targetClass
        {
            index += 1
        }

        return setCursor(
            index,
            preservingPreferredColumn: false
        )
    }

    private mutating func moveVertically(
        by amount: Int
    ) -> Bool {
        guard amount != 0 else {
            return false
        }

        let desiredColumn = preferredColumn
            ?? cursorPosition.column
        var target = cursorOffset

        if amount < 0 {
            for _ in 0..<(-amount) {
                let currentStart = lineStartOffset(
                    for: target
                )

                guard currentStart > 0 else {
                    break
                }

                let previousEnd = currentStart - 1
                let previousStart = lineStartOffset(
                    for: previousEnd
                )

                target = min(
                    previousStart + desiredColumn,
                    previousEnd
                )
            }
        } else {
            for _ in 0..<amount {
                let currentEnd = lineEndOffset(
                    for: target
                )

                guard currentEnd < text.count else {
                    break
                }

                let nextStart = currentEnd + 1
                let nextEnd = lineEndOffset(
                    for: nextStart
                )

                target = min(
                    nextStart + desiredColumn,
                    nextEnd
                )
            }
        }

        let changed = target != cursorOffset

        cursorOffset = target
        preferredColumn = desiredColumn
        return changed
    }

    @discardableResult
    private mutating func setCursor(
        _ offset: Int,
        preservingPreferredColumn: Bool
    ) -> Bool {
        let offset = min(
            max(
                0,
                offset
            ),
            text.count
        )
        let changed = cursorOffset != offset

        cursorOffset = offset

        if !preservingPreferredColumn {
            preferredColumn = nil
        }

        return changed
    }

    private func lineStartOffset(
        for requestedOffset: Int
    ) -> Int {
        let characters = Array(
            text
        )
        var offset = min(
            max(
                0,
                requestedOffset
            ),
            characters.count
        )

        while offset > 0,
              characters[offset - 1] != "\n"
        {
            offset -= 1
        }

        return offset
    }

    private func lineEndOffset(
        for requestedOffset: Int
    ) -> Int {
        let characters = Array(
            text
        )
        var offset = min(
            max(
                0,
                requestedOffset
            ),
            characters.count
        )

        while offset < characters.count,
              characters[offset] != "\n"
        {
            offset += 1
        }

        return offset
    }

    private func clamped(
        _ range: Range<Int>
    ) -> Range<Int> {
        let lower = min(
            max(
                0,
                range.lowerBound
            ),
            text.count
        )
        let upper = min(
            max(
                lower,
                range.upperBound
            ),
            text.count
        )

        return lower..<upper
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

    private enum WordClass {
        case whitespace
        case word
        case symbol
    }

    private func wordClass(
        _ character: Character
    ) -> WordClass {
        if character == " "
            || character == "\t"
            || character == "\n"
        {
            return .whitespace
        }

        if character == "_"
            || character.unicodeScalars.allSatisfy({
                CharacterSet.alphanumerics.contains(
                    $0
                )
            })
        {
            return .word
        }

        return .symbol
    }

    private static func normalized(
        _ text: String
    ) -> String {
        text
            .replacingOccurrences(
                of: "\r\n",
                with: "\n"
            )
            .replacingOccurrences(
                of: "\r",
                with: "\n"
            )
    }
}
