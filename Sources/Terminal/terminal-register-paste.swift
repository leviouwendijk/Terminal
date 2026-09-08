public enum TerminalRegisterPaste {
    public static let maximumInsertedCharacterCount =
        1_000_000

    @discardableResult
    public static func apply(
        _ value: TerminalRegisterValue,
        placement: TerminalPastePlacement,
        count rawCount: Int = 1,
        to buffer: inout TerminalTextBuffer
    ) -> Bool {
        let count = max(
            1,
            rawCount
        )

        switch value {
        case .character(let text):
            return pasteCharacter(
                text,
                placement: placement,
                count: count,
                to: &buffer
            )

        case .line(let text):
            return pasteLine(
                text,
                placement: placement,
                count: count,
                to: &buffer
            )

        case .block(let rows):
            return pasteBlock(
                rows,
                placement: placement,
                count: count,
                to: &buffer
            )
        }
    }

    private static func pasteCharacter(
        _ text: String,
        placement: TerminalPastePlacement,
        count: Int,
        to buffer: inout TerminalTextBuffer
    ) -> Bool {
        guard let payload = repeated(
            text,
            count: count
        ),
        !payload.isEmpty else {
            return false
        }

        let insertionOffset: Int

        switch placement {
        case .beforeCursor:
            insertionOffset = buffer.cursorOffset

        case .afterCursor:
            insertionOffset = buffer.cursorOffset
                < buffer.characterCount
                ? buffer.cursorOffset + 1
                : buffer.characterCount
        }

        _ = buffer.setCursor(
            offset: insertionOffset
        )

        guard buffer.insert(
            payload
        ) else {
            return false
        }

        _ = buffer.setCursor(
            offset:
                insertionOffset
                + payload.count
                - 1
        )

        return true
    }

    private static func pasteLine(
        _ text: String,
        placement: TerminalPastePlacement,
        count: Int,
        to buffer: inout TerminalTextBuffer
    ) -> Bool {
        let line = text.hasSuffix(
            "\n"
        )
            ? text
            : text + "\n"

        guard let payload = repeated(
            line,
            count: count
        ) else {
            return false
        }

        if buffer.isEmpty {
            _ = buffer.setCursor(
                offset: 0
            )

            guard buffer.insert(
                payload
            ) else {
                return false
            }

            _ = buffer.setCursor(
                offset: 0
            )
            return true
        }

        let characters = Array(
            buffer.text
        )
        let currentStart = lineStart(
            in: characters,
            containing: buffer.cursorOffset
        )
        let currentEnd = lineEnd(
            in: characters,
            containing: buffer.cursorOffset
        )
        let hasTerminatingNewline =
            currentEnd < characters.count
            && characters[currentEnd] == "\n"
        let insertionOffset: Int
        let insertion: String
        let cursorOffset: Int

        switch placement {
        case .beforeCursor:
            insertionOffset = currentStart
            insertion = payload
            cursorOffset = currentStart

        case .afterCursor:
            if hasTerminatingNewline {
                insertionOffset = currentEnd + 1
                insertion = payload
                cursorOffset = insertionOffset
            } else {
                insertionOffset = currentEnd
                insertion = "\n" + payload
                cursorOffset = insertionOffset + 1
            }
        }

        guard insertion.count
            <= maximumInsertedCharacterCount else {
            return false
        }

        _ = buffer.setCursor(
            offset: insertionOffset
        )

        guard buffer.insert(
            insertion
        ) else {
            return false
        }

        _ = buffer.setCursor(
            offset: cursorOffset
        )
        return true
    }

    private static func pasteBlock(
        _ rows: [String],
        placement: TerminalPastePlacement,
        count: Int,
        to buffer: inout TerminalTextBuffer
    ) -> Bool {
        guard !rows.isEmpty else {
            return false
        }

        let repeatedRows = rows.compactMap { row in
            repeated(
                row,
                count: count
            )
        }

        guard repeatedRows.count == rows.count else {
            return false
        }

        let sourceLayout =
            TerminalBlockSelectionGeometry.layout(
                in: buffer
            )
        let sourcePosition = sourceLayout.position(
            forCursorOffset: buffer.cursorOffset
        )
        let sourceRow = sourceLayout.rows[
            sourcePosition.row
        ]
        let insertionColumn: Int

        switch placement {
        case .beforeCursor:
            insertionColumn = sourcePosition.column

        case .afterCursor:
            insertionColumn = endpointColumn(
                forCursorOffset: buffer.cursorOffset,
                position: sourcePosition,
                row: sourceRow
            )
        }

        let requiredLineCount =
            sourcePosition.row
            + repeatedRows.count

        if buffer.lineCount < requiredLineCount {
            let missing =
                requiredLineCount
                - buffer.lineCount

            _ = buffer.setCursor(
                offset: buffer.characterCount
            )

            guard buffer.insert(
                String(
                    repeating: "\n",
                    count: missing
                )
            ) else {
                return false
            }
        }

        let layout = TerminalBlockSelectionGeometry.layout(
            in: buffer
        )
        var insertions: [
            (
                offset: Int,
                text: String,
                cursorOffset: Int
            )
        ] = []
        var insertedCharacterCount = 0

        for (
            index,
            fragment
        ) in repeatedRows.enumerated() {
            guard !fragment.isEmpty else {
                continue
            }

            let row = layout.rows[
                sourcePosition.row + index
            ]
            let offset = insertionOffset(
                atColumn: insertionColumn,
                in: row
            )
            let paddingCount = max(
                0,
                insertionColumn - row.columns
            )
            let padding = String(
                repeating: " ",
                count: paddingCount
            )
            let insertion = padding + fragment
            let (
                nextInsertedCharacterCount,
                overflow
            ) = insertedCharacterCount
                .addingReportingOverflow(
                    insertion.count
                )

            guard !overflow,
                  nextInsertedCharacterCount
                    <= maximumInsertedCharacterCount else {
                return false
            }

            insertedCharacterCount =
                nextInsertedCharacterCount

            insertions.append(
                (
                    offset: offset,
                    text: insertion,
                    cursorOffset:
                        offset + paddingCount
                )
            )
        }

        guard !insertions.isEmpty else {
            return false
        }

        for insertion in insertions.reversed() {
            _ = buffer.setCursor(
                offset: insertion.offset
            )
            _ = buffer.insert(
                insertion.text
            )
        }

        _ = buffer.setCursor(
            offset:
                insertions[
                    0
                ].cursorOffset
        )

        return true
    }

    private static func repeated(
        _ text: String,
        count: Int
    ) -> String? {
        let (
            characterCount,
            overflow
        ) = text.count.multipliedReportingOverflow(
            by: count
        )

        guard !overflow,
              characterCount
                <= maximumInsertedCharacterCount else {
            return nil
        }

        return String(
            repeating: text,
            count: count
        )
    }

    private static func endpointColumn(
        forCursorOffset offset: Int,
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

    private static func insertionOffset(
        atColumn column: Int,
        in row: TerminalTextLayoutRow
    ) -> Int {
        let offset = row.sourceOffset(
            atColumn: column
        )
        let resolvedColumn = row.column(
            atSourceOffset: offset
        )

        if resolvedColumn < column,
           offset < row.sourceRange.upperBound {
            return offset + 1
        }

        return offset
    }

    private static func lineStart(
        in characters: [Character],
        containing requestedOffset: Int
    ) -> Int {
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

    private static func lineEnd(
        in characters: [Character],
        containing requestedOffset: Int
    ) -> Int {
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
}
