import Terminal

enum TerminalTextProjectionFoundationSmoke {
    enum Failure:
        Error
    {
        case unexpectedLineNumbers
        case unexpectedDecoration
        case unexpectedDecorationWidth
    }

    static func run() throws {
        try runLineNumberProbe()
        try runDecorationProbe()
    }

    private static func runLineNumberProbe() throws {
        let presentation = TerminalLineNumberPresentation(
            mode: .hybrid
        )
        let gutterColumns = presentation.gutterColumns(
            availableColumns: 80
        )
        let current = presentation.text(
            sourceLineNumber: 3,
            currentLineNumber: 3,
            isSourceLineStart: true,
            gutterColumns: gutterColumns
        )
        let relative = presentation.text(
            sourceLineNumber: 5,
            currentLineNumber: 3,
            isSourceLineStart: true,
            gutterColumns: gutterColumns
        )
        let continuation = presentation.text(
            sourceLineNumber: 5,
            currentLineNumber: 3,
            isSourceLineStart: false,
            gutterColumns: gutterColumns
        )

        guard gutterColumns == 7,
              current.count == 7,
              current.hasSuffix(
                "3 "
              ),
              relative.count == 7,
              relative.hasSuffix(
                "2 "
              ),
              continuation == String(
                repeating: " ",
                count: 7
              ),
              presentation.style(
                sourceLineNumber: 3,
                currentLineNumber: 3
              ) == .bold,
              presentation.style(
                sourceLineNumber: 4,
                currentLineNumber: 3
              ) == .dim else {
            throw Failure.unexpectedLineNumbers
        }
    }

    private static func runDecorationProbe() throws {
        let layout = TerminalTextLayout(
            text: "a\tb",
            columns: 8,
            tabWidth: 4
        )

        guard let row = layout.rows.first else {
            throw Failure.unexpectedDecoration
        }

        let rendered = row.renderedContent(
            decorations: [
                TerminalTextDecoration(
                    sourceRange: 1..<2,
                    style: .bold
                ),
            ]
        )

        guard rendered.contains(
            "\u{001B}[1m"
        ) else {
            throw Failure.unexpectedDecoration
        }

        guard TerminalDisplay.width(
            of: rendered
        ) == 5 else {
            throw Failure.unexpectedDecorationWidth
        }
    }
}
