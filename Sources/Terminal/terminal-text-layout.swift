public enum TerminalTextWrapMode:
    Sendable,
    Codable,
    Hashable
{
    /// Break at hard column boundaries (the historical behavior).
    case character

    /// Break at word boundaries where possible, falling back to hard breaks
    /// for words wider than the column limit.
    case word
}

public struct TerminalTextLayoutRow:
    Sendable,
    Hashable
{
    public var sourceRange: Range<Int>
    public var sourceLineNumber: Int
    public var isSourceLineStart: Bool
    public var content: String
    public var columnOffsets: [Int]

    public init(
        sourceRange: Range<Int>,
        sourceLineNumber: Int = 1,
        isSourceLineStart: Bool = true,
        content: String,
        columnOffsets: [Int]
    ) {
        self.sourceRange = sourceRange
        self.sourceLineNumber = max(
            1,
            sourceLineNumber
        )
        self.isSourceLineStart = isSourceLineStart
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

    public func sourceOffset(
        atColumn requestedColumn: Int
    ) -> Int {
        let column = max(
            0,
            requestedColumn
        )

        for local in 0..<max(
            0,
            columnOffsets.count - 1
        ) {
            if column < columnOffsets[
                local + 1
            ] {
                return min(
                    sourceRange.upperBound,
                    sourceRange.lowerBound + local
                )
            }
        }

        return sourceRange.upperBound
    }

    public func sourceRange(
        overlappingColumns requestedColumns: Range<Int>
    ) -> Range<Int>? {
        let lower = max(
            0,
            requestedColumns.lowerBound
        )
        let upper = max(
            lower,
            requestedColumns.upperBound
        )

        guard lower < upper else {
            return nil
        }

        var first: Int?
        var last: Int?

        for local in 0..<max(
            0,
            columnOffsets.count - 1
        ) {
            let characterLower = columnOffsets[
                local
            ]
            let characterUpper = columnOffsets[
                local + 1
            ]

            guard characterLower < upper,
                  characterUpper > lower else {
                continue
            }

            first = first ?? local
            last = local
        }

        guard let first,
              let last else {
            return nil
        }

        return (
            sourceRange.lowerBound + first
        )..<min(
            sourceRange.upperBound,
            sourceRange.lowerBound + last + 1
        )
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
        tabWidth: Int = 4,
        wrapMode: TerminalTextWrapMode = .character
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

        // Word wrapping breaks only after spaces and tabs, so identifiers and
        // paths are never split on case transitions or punctuation.
        let wrapsWords = wrapMode == .word
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
        var sourceLineNumber = 1
        var isSourceLineStart = true
        var content = ""
        var columnOffsets = [
            0,
        ]
        var currentColumns = 0
        var rowEntries: [
            (
                sourceOffset: Int,
                display: String,
                displayColumns: Int
            )
        ] = []

        func appendRow(
            endOffset: Int
        ) {
            rows.append(
                TerminalTextLayoutRow(
                    sourceRange: rowStart..<endOffset,
                    sourceLineNumber: sourceLineNumber,
                    isSourceLineStart: isSourceLineStart,
                    content: content,
                    columnOffsets: columnOffsets
                )
            )
            rowEntries = []
            rowIndex += 1
            isSourceLineStart = false
            content = ""
            columnOffsets = [
                0,
            ]
            currentColumns = 0
        }

        var offset = 0
        while offset < characters.count {
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
                sourceLineNumber += 1
                isSourceLineStart = true
                positions[offset + 1] = TerminalTextPosition(
                    row: rowIndex,
                    column: 0
                )
                offset += 1
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

            if wrapsWords,
               currentColumns > 0,
               Self.isBreak(character),
               currentColumns + displayColumns > columns
            {
                // The word before this blank already fits: the blank (and any
                // blanks after it) hang at the end of the row with zero width
                // instead of starting the next row.
                while offset < characters.count,
                      Self.isBreak(characters[offset])
                {
                    positions[offset] = TerminalTextPosition(
                        row: rowIndex,
                        column: currentColumns
                    )
                    columnOffsets.append(
                        currentColumns
                    )
                    offset += 1
                }
                // A newline ends this row itself.
                if offset < characters.count,
                   characters[offset] == "\n"
                {
                    continue
                }
                appendRow(
                    endOffset: offset
                )
                rowStart = offset
                positions[offset] = TerminalTextPosition(
                    row: rowIndex,
                    column: 0
                )
                continue
            }

            if currentColumns > 0,
               currentColumns + displayColumns > columns
            {
                var spaceOffset: Int?
                if wrapsWords {
                    // Only a blank that follows visible text on this row is a
                    // break; breaking inside leading indentation would leave a
                    // row of nothing but blanks.
                    for candidate in stride(
                        from: offset - 1,
                        through: rowStart,
                        by: -1
                    ) where Self.isBreak(characters[candidate]) {
                        if characters[rowStart..<candidate].contains(where: { !Self.isBreak($0) }) {
                            spaceOffset = candidate
                        }
                        break
                    }
                }

                if let spaceOffset {
                    // Word-wrap: break at the most recent space boundary so the
                    // word being overflowed moves to the next row intact rather
                    // than being split mid-word.
                    let newRowEnd = spaceOffset + 1

                    // Trim this row back to end right after the space.
                    while let last = rowEntries.last,
                          last.sourceOffset > spaceOffset {
                        rowEntries.removeLast()
                    }
                    content = ""
                    columnOffsets = [
                        0,
                    ]
                    currentColumns = 0
                    for entry in rowEntries {
                        content += entry.display
                        currentColumns += entry.displayColumns
                        columnOffsets.append(
                            currentColumns
                        )
                    }
                    appendRow(
                        endOffset: newRowEnd
                    )
                    rowStart = newRowEnd

                    // Reprocess moved characters through normal placement:
                    // tabs may grow at their new columns and overflow again.
                    offset = newRowEnd
                    continue
                } else {
                    // No word boundary available: hard-break mid-word.
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
                }
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
            rowEntries.append(
                (
                    sourceOffset: offset,
                    display: display,
                    displayColumns: displayColumns
                )
            )
            positions[offset + 1] = TerminalTextPosition(
                row: rowIndex,
                column: currentColumns
            )
            offset += 1
        }

        rows.append(
            TerminalTextLayoutRow(
                sourceRange: rowStart..<characters.count,
                sourceLineNumber: sourceLineNumber,
                isSourceLineStart: isSourceLineStart,
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

    private static func isBreak(
        _ character: Character
    ) -> Bool {
        character == " " || character == "\t"
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
