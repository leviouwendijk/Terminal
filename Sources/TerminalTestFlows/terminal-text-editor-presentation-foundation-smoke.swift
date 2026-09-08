import Terminal

enum TerminalTextEditorPresentationFoundationSmoke {
    static func run() throws {
        try runStableLineNumberGutterProbe()
        try runHybridLineNumberAndIndentationProbe()
        try runWrappedLineNumberProbe()
    }

    private static func runHybridLineNumberAndIndentationProbe() throws {
        let text = "alpha\n    beta\n        gamma\nomega"
        var editor = TerminalTextEditor(
            text: text,
            cursorOffset: "alpha\n    beta\n        ".count,
            mode: .normal
        )
        var frame = TerminalFrame(
            rows: 4,
            columns: 24
        )

        editor.render(
            into: &frame,
            in: TerminalRegion(
                rows: 4,
                columns: 24
            ),
            presentation: TerminalTextEditorPresentation(
                lineNumbers: .hybrid,
                indentationGuides: TerminalIndentationGuideOptions(
                    isEnabled: true,
                    width: 4,
                    glyph: "│"
                )
            )
        )

        let rendered = (0..<4).map {
            renderedLine(
                frame,
                row: $0
            )
        }
        let expected = [
            "     2 alpha",
            "     1 │   beta",
            "     3 │   │   gamma",
            "     1 omega",
        ]

        guard rendered == expected else {
            throw TerminalTestFailure(
                probe: "text editor hybrid line numbers and indentation guides",
                expectation: String(
                    describing: expected
                ),
                observed: String(
                    describing: rendered
                )
            )
        }
    }

    private static func runStableLineNumberGutterProbe() throws {
        let presentation = TerminalTextEditorPresentation(
            lineNumbers: .absolute
        )
        let widths = [
            1,
            9,
            10,
            99,
            100,
            999,
            1_000,
            99_999,
            100_000,
        ].map {
            presentation.gutterColumns(
                lineCount: $0,
                availableColumns: 80
            )
        }
        let expected = Array(
            repeating: 7,
            count: widths.count
        )

        guard widths == expected else {
            throw TerminalTestFailure(
                probe: "text editor stable six-digit line-number gutter",
                expectation: String(
                    describing: expected
                ),
                observed: String(
                    describing: widths
                )
            )
        }
    }

    private static func runWrappedLineNumberProbe() throws {
        let text = "abcdefghij\nz"
        var editor = TerminalTextEditor(
            text: text,
            cursorOffset: text.count,
            mode: .normal
        )
        var frame = TerminalFrame(
            rows: 3,
            columns: 12
        )

        editor.render(
            into: &frame,
            in: TerminalRegion(
                rows: 3,
                columns: 12
            ),
            presentation: TerminalTextEditorPresentation(
                lineNumbers: .hybrid
            )
        )

        let rendered = (0..<3).map {
            renderedLine(
                frame,
                row: $0
            )
        }
        let expected = [
            "     1 abcde",
            "       fghij",
            "     2 z",
        ]

        guard rendered == expected else {
            throw TerminalTestFailure(
                probe: "text editor wrapped line-number gutter",
                expectation: String(
                    describing: expected
                ),
                observed: String(
                    describing: rendered
                )
            )
        }
    }

    private static func renderedLine(
        _ frame: TerminalFrame,
        row: Int
    ) -> String {
        stripANSI(
            frame.spans(
                inRow: row
            )
            .sorted {
                $0.leading < $1.leading
            }
            .map(
                \.content
            )
            .joined()
        )
    }
}
