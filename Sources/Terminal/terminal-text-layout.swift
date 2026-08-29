public struct TerminalTextLayoutRow:
    Sendable,
    Hashable
{
    public var sourceRange: Range<Int>
    public var content: String
    public var columnOffsets: [Int]

    public init(
        sourceRange: Range<Int>,
        content: String,
        columnOffsets: [Int]
    ) {
        self.sourceRange = sourceRange
        self.content = content
        self.columnOffsets = columnOffsets
    }

    public var columns: Int {
        columnOffsets.last ?? 0
    }

    public func column(
        atSourceOffset offset: Int
    ) -> Int {
        let local = min(
            max(
                0,
                offset - sourceRange.lowerBound
            ),
            max(
                0,
                columnOffsets.count - 1
            )
        )

        return columnOffsets[local]
    }
}

public struct TerminalTextLayout:
    Sendable,
    Hashable
{
    public var columns: Int
    public var rows: [TerminalTextLayoutRow]

    private var cursorPositions: [TerminalTextPosition]

    public init(
        text: String,
        columns: Int,
        tabWidth: Int = 4
    ) {
        let columns = max(
            1,
            columns
        )
        let tabWidth = max(
            1,
            tabWidth
        )
        let characters = Array(
            text
        )
        var rows: [TerminalTextLayoutRow] = []
        var positions = Array(
            repeating: TerminalTextPosition(
                row: 0,
                column: 0
            ),
            count: characters.count + 1
        )
        var rowIndex = 0
        var rowStart = 0
        var content = ""
        var columnOffsets = [
            0,
        ]
        var currentColumns = 0

        func appendRow(
            endOffset: Int
        ) {
            rows.append(
                TerminalTextLayoutRow(
                    sourceRange: rowStart..<endOffset,
                    content: content,
                    columnOffsets: columnOffsets
                )
            )
            rowIndex += 1
            content = ""
            columnOffsets = [
                0,
            ]
            currentColumns = 0
        }

        for offset in characters.indices {
            let character = characters[offset]

            if character == "\n" {
                positions[offset] = TerminalTextPosition(
                    row: rowIndex,
                    column: currentColumns
                )
                appendRow(
                    endOffset: offset
                )
                rowStart = offset + 1
                positions[offset + 1] = TerminalTextPosition(
                    row: rowIndex,
                    column: 0
                )
                continue
            }

            var display = Self.display(
                character,
                column: currentColumns,
                tabWidth: tabWidth
            )
            var displayColumns = TerminalDisplay.width(
                of: display
            )

            if currentColumns > 0,
               currentColumns + displayColumns > columns
            {
                appendRow(
                    endOffset: offset
                )
                rowStart = offset
                positions[offset] = TerminalTextPosition(
                    row: rowIndex,
                    column: 0
                )
                display = Self.display(
                    character,
                    column: 0,
                    tabWidth: tabWidth
                )
                displayColumns = TerminalDisplay.width(
                    of: display
                )
            } else {
                positions[offset] = TerminalTextPosition(
                    row: rowIndex,
                    column: currentColumns
                )
            }

            if displayColumns > columns {
                display = TerminalDisplay.fitted(
                    display,
                    columns: columns
                )
                displayColumns = columns
            }

            content += display
            currentColumns += displayColumns
            columnOffsets.append(
                currentColumns
            )
            positions[offset + 1] = TerminalTextPosition(
                row: rowIndex,
                column: currentColumns
            )
        }

        rows.append(
            TerminalTextLayoutRow(
                sourceRange: rowStart..<characters.count,
                content: content,
                columnOffsets: columnOffsets
            )
        )

        self.columns = columns
        self.rows = rows
        self.cursorPositions = positions
    }

    public func position(
        forCursorOffset offset: Int
    ) -> TerminalTextPosition {
        let offset = min(
            max(
                0,
                offset
            ),
            max(
                0,
                cursorPositions.count - 1
            )
        )

        return cursorPositions[offset]
    }

    private static func display(
        _ character: Character,
        column: Int,
        tabWidth: Int
    ) -> String {
        if character == "\t" {
            let remainder = column % tabWidth
            let width = remainder == 0
                ? tabWidth
                : tabWidth - remainder

            return String(
                repeating: " ",
                count: width
            )
        }

        let isControl = character.unicodeScalars.allSatisfy {
            $0.properties.generalCategory == .control
        }

        return isControl
            ? "�"
            : String(
                character
            )
    }
}
