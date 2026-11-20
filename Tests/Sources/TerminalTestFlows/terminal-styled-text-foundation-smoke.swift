import Terminal

enum TerminalStyledTextFoundationSmoke {
    enum Failure:
        Error
    {
        case unexpectedBasicRange
        case unexpectedBaseComposition
        case unexpectedOverlapComposition
        case unexpectedClipping
        case unexpectedWrapping
        case unexpectedUnicode
        case unexpectedTabMapping
    }

    static func run() throws {
        try runBasicRangeProbe()
        try runBaseCompositionProbe()
        try runOverlapCompositionProbe()
        try runClippingProbe()
        try runWrappingProbe()
        try runUnicodeProbe()
        try runTabMappingProbe()
    }

    private static func runBasicRangeProbe() throws {
        let rendered = TerminalStyledText(
            text: "some_draft_name",
            spans: [
                TerminalTextStyleSpan(
                    sourceRange: 5..<10,
                    style: TerminalStyle(
                        .green
                    )
                ),
            ]
        ).renderedRows(
            columns: 80
        )

        guard rendered.count == 1,
              stripANSI(
                rendered[0]
              ) == "some_draft_name",
              rendered[0].contains(
                TerminalStyle(
                    .green
                ).apply(
                    "draft"
                )
              ) else {
            throw Failure.unexpectedBasicRange
        }
    }

    private static func runBaseCompositionProbe() throws {
        let rendered = TerminalStyledText(
            text: "abcXYZ",
            style: .dim,
            spans: [
                TerminalTextStyleSpan(
                    sourceRange: 0..<3,
                    style: .bold
                ),
            ]
        ).renderedRows(
            columns: 80
        )

        guard rendered.count == 1,
              rendered[0].contains(
                TerminalStyle(
                    codes: [
                        .dim,
                        .bold,
                    ]
                ).apply(
                    "abc"
                )
              ),
              rendered[0].contains(
                TerminalStyle.dim.apply(
                    "XYZ"
                )
              ),
              stripANSI(
                rendered[0]
              ) == "abcXYZ" else {
            throw Failure.unexpectedBaseComposition
        }
    }

    private static func runOverlapCompositionProbe() throws {
        let rendered = TerminalStyledText(
            text: "abcdefgh",
            style: .dim,
            spans: [
                TerminalTextStyleSpan(
                    sourceRange: 1..<5,
                    style: .bold
                ),
                TerminalTextStyleSpan(
                    sourceRange: 3..<7,
                    style: TerminalStyle(
                        .green
                    )
                ),
            ]
        ).renderedRows(
            columns: 80
        )

        guard rendered.count == 1,
              rendered[0].contains(
                TerminalStyle(
                    codes: [
                        .dim,
                        .bold,
                        .green,
                    ]
                ).apply(
                    "de"
                )
              ),
              rendered[0].contains(
                TerminalStyle(
                    codes: [
                        .dim,
                        .green,
                    ]
                ).apply(
                    "fg"
                )
              ),
              stripANSI(
                rendered[0]
              ) == "abcdefgh" else {
            throw Failure.unexpectedOverlapComposition
        }
    }

    private static func runClippingProbe() throws {
        let rendered = TerminalStyledText(
            text: "abcdefgh",
            spans: [
                TerminalTextStyleSpan(
                    sourceRange: -5..<3,
                    style: TerminalStyle(
                        .green
                    )
                ),
                TerminalTextStyleSpan(
                    sourceRange: 4..<4,
                    style: .bold
                ),
                TerminalTextStyleSpan(
                    sourceRange: 6..<99,
                    style: .bold
                ),
            ]
        ).renderedRows(
            columns: 80
        )

        guard rendered.count == 1,
              rendered[0].contains(
                TerminalStyle(
                    .green
                ).apply(
                    "abc"
                )
              ),
              rendered[0].contains(
                TerminalStyle.bold.apply(
                    "gh"
                )
              ),
              stripANSI(
                rendered[0]
              ) == "abcdefgh" else {
            throw Failure.unexpectedClipping
        }
    }

    private static func runWrappingProbe() throws {
        let rendered = TerminalStyledText(
            text: "abcdefgh",
            spans: [
                TerminalTextStyleSpan(
                    sourceRange: 2..<6,
                    style: TerminalStyle(
                        .green
                    )
                ),
            ]
        ).renderedRows(
            columns: 4
        )

        guard rendered.count == 2,
              rendered.map({
                stripANSI(
                    $0
                )
              }) == [
                "abcd",
                "efgh",
              ],
              rendered[0].contains(
                TerminalStyle(
                    .green
                ).apply(
                    "cd"
                )
              ),
              rendered[1].contains(
                TerminalStyle(
                    .green
                ).apply(
                    "ef"
                )
              ),
              rendered.allSatisfy({
                TerminalDisplay.width(
                    of: $0
                ) == 4
              }) else {
            throw Failure.unexpectedWrapping
        }
    }

    private static func runUnicodeProbe() throws {
        let rendered = TerminalStyledText(
            text: "🐶Foo🐾bar",
            spans: [
                TerminalTextStyleSpan(
                    sourceRange: 1..<4,
                    style: .bold
                ),
            ]
        ).renderedRows(
            columns: 80
        )

        guard rendered.count == 1,
              stripANSI(
                rendered[0]
              ) == "🐶Foo🐾bar",
              rendered[0].contains(
                TerminalStyle.bold.apply(
                    "Foo"
                )
              ) else {
            throw Failure.unexpectedUnicode
        }
    }

    private static func runTabMappingProbe() throws {
        let rendered = TerminalStyledText(
            text: "\tX",
            spans: [
                TerminalTextStyleSpan(
                    sourceRange: 1..<2,
                    style: TerminalStyle(
                        .green
                    )
                ),
            ]
        ).renderedRows(
            columns: 8,
            tabWidth: 4
        )

        guard rendered.count == 1,
              stripANSI(
                rendered[0]
              ) == "    X",
              TerminalDisplay.width(
                of: rendered[0]
              ) == 5,
              rendered[0].contains(
                TerminalStyle(
                    .green
                ).apply(
                    "X"
                )
              ) else {
            throw Failure.unexpectedTabMapping
        }
    }
}
