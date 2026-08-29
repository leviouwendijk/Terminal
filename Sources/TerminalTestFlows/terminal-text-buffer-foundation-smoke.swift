import Terminal

enum TerminalTextBufferFoundationSmoke {
    enum Failure:
        Error
    {
        case unexpectedEditing
        case unexpectedVerticalMotion
        case unexpectedWordMotion
        case unexpectedLayout
        case unexpectedUnicodeLayout
    }

    static func run() throws {
        try runEditingProbe()
        try runVerticalMotionProbe()
        try runWordMotionProbe()
        try runLayoutProbe()
        try runUnicodeLayoutProbe()
    }

    private static func runEditingProbe() throws {
        var buffer = TerminalTextBuffer(
            text: "one\r\ntwo",
            cursorOffset: 3
        )

        guard buffer.text == "one\ntwo",
              buffer.cursorPosition == TerminalTextPosition(
                row: 0,
                column: 3
              ) else {
            throw Failure.unexpectedEditing
        }

        _ = buffer.insertNewline()
        _ = buffer.insert(
            "middle"
        )

        guard buffer.text == "one\nmiddle\ntwo",
              buffer.cursorPosition == TerminalTextPosition(
                row: 1,
                column: 6
              ) else {
            throw Failure.unexpectedEditing
        }

        _ = buffer.deleteBackward()

        guard buffer.text == "one\nmiddl\ntwo" else {
            throw Failure.unexpectedEditing
        }
    }

    private static func runVerticalMotionProbe() throws {
        var buffer = TerminalTextBuffer(
            text: "abcdef\nx\n123456",
            cursorOffset: 5
        )

        guard buffer.cursorPosition == TerminalTextPosition(
            row: 0,
            column: 5
        ) else {
            throw Failure.unexpectedVerticalMotion
        }

        _ = buffer.moveDown()

        guard buffer.cursorPosition == TerminalTextPosition(
            row: 1,
            column: 1
        ) else {
            throw Failure.unexpectedVerticalMotion
        }

        _ = buffer.moveDown()

        guard buffer.cursorPosition == TerminalTextPosition(
            row: 2,
            column: 5
        ) else {
            throw Failure.unexpectedVerticalMotion
        }

        _ = buffer.moveUp(
            by: 2
        )

        guard buffer.cursorPosition == TerminalTextPosition(
            row: 0,
            column: 5
        ) else {
            throw Failure.unexpectedVerticalMotion
        }
    }

    private static func runWordMotionProbe() throws {
        var buffer = TerminalTextBuffer(
            text: "alpha  beta.gamma",
            cursorOffset: 0
        )

        _ = buffer.moveWordForward()

        guard buffer.cursorOffset == 7 else {
            throw Failure.unexpectedWordMotion
        }

        _ = buffer.moveWordForward()

        guard buffer.cursorOffset == 11 else {
            throw Failure.unexpectedWordMotion
        }

        _ = buffer.moveWordBackward()

        guard buffer.cursorOffset == 7 else {
            throw Failure.unexpectedWordMotion
        }
    }

    private static func runLayoutProbe() throws {
        let layout = TerminalTextLayout(
            text: "abcdef\nxy",
            columns: 3
        )

        guard layout.rows.map(\.content) == [
            "abc",
            "def",
            "xy",
        ],
        layout.position(
            forCursorOffset: 4
        ) == TerminalTextPosition(
            row: 1,
            column: 1
        ),
        layout.position(
            forCursorOffset: 7
        ) == TerminalTextPosition(
            row: 2,
            column: 0
        ) else {
            throw Failure.unexpectedLayout
        }

        let tabbed = TerminalTextLayout(
            text: "a\tb",
            columns: 8,
            tabWidth: 4
        )

        guard tabbed.rows.first?.content == "a   b",
              tabbed.position(
                forCursorOffset: 2
              ) == TerminalTextPosition(
                row: 0,
                column: 4
              ) else {
            throw Failure.unexpectedLayout
        }
    }

    private static func runUnicodeLayoutProbe() throws {
        let layout = TerminalTextLayout(
            text: "a🙂b",
            columns: 3
        )

        let emojiWidth = TerminalDisplay.width(
            of: "🙂"
        )
        let emojiSequenceWidth = TerminalDisplay.width(
            of: "❤️"
        )
        let combiningWidth = TerminalDisplay.width(
            of: "e\u{0301}"
        )
        let rowContents = layout.rows.map(\.content)
        let rowWidths = layout.rows.map {
            TerminalDisplay.width(
                of: $0.content
            )
        }
        let offset1 = layout.position(
            forCursorOffset: 1
        )
        let offset2 = layout.position(
            forCursorOffset: 2
        )
        let offset3 = layout.position(
            forCursorOffset: 3
        )

        guard emojiWidth == 2,
              emojiSequenceWidth == 2,
              combiningWidth == 1,
              rowContents == [
                "a🙂",
                "b",
              ],
              rowWidths == [
                3,
                1,
              ],
              offset1 == TerminalTextPosition(
                row: 0,
                column: 1
              ),
              offset2 == TerminalTextPosition(
                row: 1,
                column: 0
              ),
              offset3 == TerminalTextPosition(
                row: 1,
                column: 1
              ) else {
            throw TerminalTestFailure(
                probe: "TerminalTextLayout Unicode soft-wrap",
                expectation: "emojiWidth=2 emojiSequenceWidth=2 combiningWidth=1 rows=[a🙂, b] widths=[3, 1] offsets=[0:1, 1:0, 1:1]",
                observed: "emojiWidth=\(emojiWidth) emojiSequenceWidth=\(emojiSequenceWidth) combiningWidth=\(combiningWidth) rows=\(rowContents) widths=\(rowWidths) offsets=[\(offset1.row):\(offset1.column), \(offset2.row):\(offset2.column), \(offset3.row):\(offset3.column)]"
            )
        }
    }
}
