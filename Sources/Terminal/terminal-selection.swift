import Swim

public struct TerminalSelection:
    Sendable,
    Codable,
    Hashable
{
    public let anchor: Int
    public var cursor: Int
    public var kind: Swim.SelectionKind
    public var blockPreferredColumn: Int?

    public init(
        anchor: Int,
        cursor: Int,
        kind: Swim.SelectionKind = .character,
        blockPreferredColumn: Int? = nil
    ) {
        self.anchor = anchor
        self.cursor = cursor
        self.kind = kind
        self.blockPreferredColumn = blockPreferredColumn
    }

    public func resolved(
        in buffer: TerminalTextBuffer,
        tabWidth: Int = 4
    ) -> TerminalResolvedSelection? {
        switch kind {
        case .character:
            guard let range = characterRange(
                characterCount: buffer.characterCount
            ) else {
                return nil
            }

            return .contiguous(
                range: range,
                kind: .character
            )

        case .line:
            guard let range = lineRange(
                in: buffer.text
            ) else {
                return nil
            }

            return .contiguous(
                range: range,
                kind: .line
            )

        case .block:
            return .block(
                blockSelection(
                    in: buffer,
                    tabWidth: tabWidth
                )
            )
        }
    }

    public func resolvedRange(
        in buffer: TerminalTextBuffer
    ) -> Range<Int>? {
        resolved(
            in: buffer
        )?.contiguousRange
    }

    private func characterRange(
        characterCount: Int
    ) -> Range<Int>? {
        let anchor = min(
            max(
                0,
                anchor
            ),
            characterCount
        )
        let cursor = min(
            max(
                0,
                cursor
            ),
            characterCount
        )
        let lower = min(
            anchor,
            cursor
        )
        let upper = max(
            anchor,
            cursor
        )

        if lower == upper {
            guard lower < characterCount else {
                return nil
            }

            return lower..<(lower + 1)
        }

        return lower..<min(
            characterCount,
            upper + 1
        )
    }

    private func lineRange(
        in text: String
    ) -> Range<Int>? {
        let characters = Array(
            text
        )

        guard !characters.isEmpty else {
            return nil
        }

        let lastSourceOffset = characters.count - 1
        let anchor = min(
            max(
                0,
                self.anchor
            ),
            lastSourceOffset
        )
        let cursor = min(
            max(
                0,
                self.cursor
            ),
            lastSourceOffset
        )
        let lowerOffset = min(
            anchor,
            cursor
        )
        let upperOffset = max(
            anchor,
            cursor
        )
        let lower = lineStart(
            containing: lowerOffset,
            characters: characters
        )
        let upper = lineEnd(
            containing: upperOffset,
            characters: characters
        )

        guard lower < upper else {
            return nil
        }

        return lower..<upper
    }

    private func blockSelection(
        in buffer: TerminalTextBuffer,
        tabWidth: Int
    ) -> TerminalResolvedBlockSelection {
        let layout = TerminalBlockSelectionGeometry.layout(
            in: buffer,
            tabWidth: tabWidth
        )
        let anchorOffset = min(
            max(
                0,
                anchor
            ),
            buffer.characterCount
        )
        let cursorOffset = min(
            max(
                0,
                cursor
            ),
            buffer.characterCount
        )
        let anchorPosition = layout.position(
            forCursorOffset: anchorOffset
        )
        let cursorPosition = layout.position(
            forCursorOffset: cursorOffset
        )
        let anchorRow = layout.rows[
            anchorPosition.row
        ]
        let cursorRow = layout.rows[
            cursorPosition.row
        ]
        let anchorEndColumn = endpointEndColumn(
            offset: anchorOffset,
            position: anchorPosition,
            row: anchorRow
        )
        let cursorEndColumn = endpointEndColumn(
            offset: cursorOffset,
            position: cursorPosition,
            row: cursorRow
        )
        let lowerColumn = min(
            anchorPosition.column,
            cursorPosition.column
        )
        let upperColumn = max(
            anchorEndColumn,
            cursorEndColumn
        )
        let columns = lowerColumn..<upperColumn
        let lowerRow = min(
            anchorPosition.row,
            cursorPosition.row
        )
        let upperRow = max(
            anchorPosition.row,
            cursorPosition.row
        )
        let rows = (lowerRow...upperRow).map { rowIndex in
            TerminalResolvedBlockRow(
                row: rowIndex,
                sourceRange:
                    layout.rows[
                        rowIndex
                    ].sourceRange(
                        overlappingColumns: columns
                    )
            )
        }

        return TerminalResolvedBlockSelection(
            columns: columns,
            rows: rows
        )
    }

    private func endpointEndColumn(
        offset: Int,
        position: TerminalTextPosition,
        row: TerminalTextLayoutRow
    ) -> Int {
        guard offset >= row.sourceRange.lowerBound,
              offset < row.sourceRange.upperBound else {
            return position.column
        }

        return row.column(
            atSourceOffset: offset + 1
        )
    }

    private func lineStart(
        containing offset: Int,
        characters: [Character]
    ) -> Int {
        var offset = offset

        while offset > 0,
              characters[offset - 1] != "\n"
        {
            offset -= 1
        }

        return offset
    }

    private func lineEnd(
        containing offset: Int,
        characters: [Character]
    ) -> Int {
        var offset = offset

        while offset < characters.count,
              characters[offset] != "\n"
        {
            offset += 1
        }

        if offset < characters.count,
           characters[offset] == "\n"
        {
            offset += 1
        }

        return offset
    }
}

public enum TerminalResolvedSelection:
    Sendable,
    Codable,
    Hashable
{
    case contiguous(
        range: Range<Int>,
        kind: Swim.SelectionKind
    )
    case block(TerminalResolvedBlockSelection)

    public var contiguousRange: Range<Int>? {
        guard case .contiguous(
            let range,
            _
        ) = self else {
            return nil
        }

        return range
    }

    public var sourceRanges: [Range<Int>] {
        switch self {
        case .contiguous(let range, _):
            return [
                range,
            ]

        case .block(let block):
            return block.sourceRanges
        }
    }
}

public struct TerminalResolvedBlockSelection:
    Sendable,
    Codable,
    Hashable
{
    public var columns: Range<Int>
    public var rows: [TerminalResolvedBlockRow]

    public init(
        columns: Range<Int>,
        rows: [TerminalResolvedBlockRow]
    ) {
        self.columns = columns
        self.rows = rows
    }

    public var sourceRanges: [Range<Int>] {
        rows.compactMap(
            \.sourceRange
        )
    }
}

public struct TerminalResolvedBlockRow:
    Sendable,
    Codable,
    Hashable
{
    public var row: Int
    public var sourceRange: Range<Int>?

    public init(
        row: Int,
        sourceRange: Range<Int>?
    ) {
        self.row = row
        self.sourceRange = sourceRange
    }
}

public enum TerminalBlockSelectionGeometry {
    public static func layout(
        in buffer: TerminalTextBuffer,
        tabWidth: Int = 4
    ) -> TerminalTextLayout {
        TerminalTextLayout(
            text: buffer.text,
            columns: unwrappedColumns(
                for: buffer.text,
                tabWidth: tabWidth
            ),
            tabWidth: tabWidth
        )
    }

    public static func position(
        forSourceOffset offset: Int,
        in buffer: TerminalTextBuffer,
        tabWidth: Int = 4
    ) -> TerminalTextPosition {
        layout(
            in: buffer,
            tabWidth: tabWidth
        ).position(
            forCursorOffset: offset
        )
    }

    public static func sourceOffset(
        row: Int,
        column: Int,
        in buffer: TerminalTextBuffer,
        tabWidth: Int = 4
    ) -> Int {
        let layout = layout(
            in: buffer,
            tabWidth: tabWidth
        )
        let row = min(
            max(
                0,
                row
            ),
            max(
                0,
                layout.rows.count - 1
            )
        )

        return layout.rows[
            row
        ].sourceOffset(
            atColumn: column
        )
    }

    private static func unwrappedColumns(
        for text: String,
        tabWidth rawTabWidth: Int
    ) -> Int {
        let tabWidth = max(
            1,
            rawTabWidth
        )
        var current = 0
        var maximum = 1

        for character in text {
            if character == "\n" {
                maximum = max(
                    maximum,
                    current
                )
                current = 0
                continue
            }

            let width = character == "\t"
                ? tabWidth
                : max(
                    1,
                    TerminalDisplay.width(
                        of: String(
                            character
                        )
                    )
                )
            let (
                next,
                overflow
            ) = current.addingReportingOverflow(
                width
            )

            current = overflow
                ? Int.max
                : next
            maximum = max(
                maximum,
                current
            )
        }

        return max(
            1,
            maximum
        )
    }
}

