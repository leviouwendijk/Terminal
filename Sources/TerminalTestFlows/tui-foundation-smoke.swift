import Difference
import Terminal

enum TerminalTUIFoundationSmoke {
    enum Failure:
        Error
    {
        case unexpectedViewport
        case unexpectedTextInput
        case unexpectedDisplay
        case unexpectedBlockWrap
        case unexpectedDifferenceEndOfFile
        case unexpectedFrame
        case unexpectedFrameComposition
        case unexpectedFrameCompositionWidth
        case unexpectedFrameCompositionBorder
        case unexpectedHorizontalLayout
        case unexpectedVerticalLayout
    }

    static func run() throws {
        try runViewportProbe()
        try runScrollableDocumentRevealProbe()
        try runTextInputProbe()
        try runDisplayProbe()
        try runBlockWrapProbe()
        try runDifferenceEndOfFileProbe()
        try runFrameProbe()
        try runFrameCompositionProbe()
        try TerminalControlFoundationSmoke.run()
        try TerminalOverlayFoundationSmoke.run()
        try TerminalInteractionFoundationSmoke.run()
        try TerminalInputFoundationSmoke.run()
        try TerminalTextBufferFoundationSmoke.run()
        try TerminalTextEditorFoundationSmoke.run()
        try TerminalTimelineFoundationSmoke.run()
        try runLayoutProbe()

        print(
            "tui foundation smoke passed"
        )
    }

    private static func runViewportProbe() throws {
        var viewport = TerminalViewport(
            contentRows: 100,
            visibleRows: 10
        )

        viewport.pageDown()
        viewport.reveal(
            row: 50,
            margin: 2
        )

        guard viewport.visibleRange.contains(50) else {
            throw Failure.unexpectedViewport
        }

        viewport.moveToEnd()

        guard viewport.offset == 90,
              viewport.isAtEnd else {
            throw Failure.unexpectedViewport
        }
    }

    private static func runScrollableDocumentRevealProbe() throws {
        var document = TerminalScrollableDocument(
            lines: (0..<20).map(String.init),
            visibleRows: 5,
            followEnd: true
        )

        document.reveal(
            row: 3,
            margin: 1
        )

        guard document.viewport.offset == 2,
              document.viewport.visibleRange.contains(3),
              !document.isFollowingEnd else {
            throw TerminalTestFailure(
                probe: "TerminalScrollableDocument semantic reveal",
                expectation: "offset=2 selectedRowVisible=true followingEnd=false",
                observed: "offset=\(document.viewport.offset) selectedRowVisible=\(document.viewport.visibleRange.contains(3)) followingEnd=\(document.isFollowingEnd)"
            )
        }

        document.update(
            lines: (0..<25).map(String.init),
            visibleRows: 5
        )

        guard document.viewport.offset == 2 else {
            throw TerminalTestFailure(
                probe: "TerminalScrollableDocument reveal disables end-follow",
                expectation: "offset remains 2 after content growth",
                observed: "offset=\(document.viewport.offset) followingEnd=\(document.isFollowingEnd)"
            )
        }
    }

    private static func runTextInputProbe() throws {
        var input = TerminalTextInput(
            text: "ac",
            cursorOffset: 1
        )

        _ = input.handle(
            .char("b")
        )
        _ = input.handle(
            .left
        )
        _ = input.handle(
            .backspace
        )

        guard input.text == "bc",
              input.cursorOffset == 0,
              input.handle(
                .enter
              ) == .submitRequested else {
            throw Failure.unexpectedTextInput
        }
    }

    private static func runDisplayProbe() throws {
        let styled = TerminalStyle.bold.apply(
            "ready"
        )

        guard TerminalDisplay.width(
            of: styled
        ) == 5 else {
            throw Failure.unexpectedDisplay
        }

        guard TerminalDisplay.clipped(
            "abcdef",
            columns: 4
        ) == "abcd" else {
            throw Failure.unexpectedDisplay
        }

        guard TerminalDisplay.fitted(
            "abc",
            columns: 5
        ) == "abc  " else {
            throw Failure.unexpectedDisplay
        }

        let sliced = TerminalDisplay.slice(
            TerminalStyle.bold.apply(
                "abcdef"
            ),
            columns: 2..<5
        )

        guard TerminalDisplay.width(
            of: sliced
        ) == 3,
        sliced.contains(
            "cde"
        ) else {
            throw Failure.unexpectedDisplay
        }

        guard TerminalDisplay.width(
            of: "│"
        ) == 1,
        TerminalDisplay.width(
            of: "─"
        ) == 1,
        TerminalDisplay.width(
            of: "┌"
        ) == 1,
        TerminalDisplay.width(
            of: "┘"
        ) == 1,
        TerminalDisplay.width(
            of: "┌────┐"
        ) == 6 else {
            throw Failure.unexpectedDisplay
        }

        let leadingSlice = TerminalDisplay.slice(
            TerminalStyle.dim.apply(
                "│abc"
            ),
            columns: 0..<1
        )

        guard TerminalDisplay.width(
            of: leadingSlice
        ) == 1,
        leadingSlice.contains(
            "│"
        ) else {
            throw Failure.unexpectedDisplay
        }
    }

    private static func runBlockWrapProbe() throws {
        let rendered = TerminalBlock(
            title: "intent",
            body: "reusable terminal overlay",
            layout: TerminalBlockLayout(
                blankLinesAfter: 0
            )
        ).render(
            width: 10
        )

        guard rendered.contains(
            "reusable\nterminal\noverlay"
        ) else {
            throw Failure.unexpectedBlockWrap
        }
    }

    private static func runDifferenceEndOfFileProbe() throws {
        let difference = TextDiffer.diff(
            old: "one\ntwo\nthree\nfour\nfive\nsix",
            new: "one\nchanged\nthree\nfour\nfive\nsix"
        )
        let defaultRendered = stripANSI(
            TerminalDifferenceRenderer.render(
                difference
            )
        )
        let rendered = stripANSI(
            TerminalDifferenceRenderer.render(
                difference,
                options: .init(
                    base: .init(
                        contextLineCount: 1,
                        showEndOfFile: true
                    )
                )
            )
        )
        let lines = rendered
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .map(String.init)

        guard !defaultRendered.contains(
            "EOF"
        ),
        lines.count >= 2,
        lines[lines.count - 2] == " ...",
        lines[lines.count - 1] == "EOF │" else {
            throw Failure.unexpectedDifferenceEndOfFile
        }
    }

    private static func runFrameProbe() throws {
        var frame = TerminalFrame(
            rows: 4,
            columns: 12
        )

        frame.write(
            [
                "left",
                "tail",
            ],
            in: TerminalRegion(
                top: 1,
                leading: 2,
                rows: 2,
                columns: 5
            )
        )

        guard frame.spans(
            inRow: 1
        ) == [
            TerminalFrameSpan(
                row: 1,
                leading: 2,
                columns: 5,
                content: "left"
            ),
        ] else {
            throw Failure.unexpectedFrame
        }

        guard frame.spans(
            inRow: 2
        ) == [
            TerminalFrameSpan(
                row: 2,
                leading: 2,
                columns: 5,
                content: "tail"
            ),
        ] else {
            throw Failure.unexpectedFrame
        }
    }

    private static func runFrameCompositionProbe() throws {
        var frame = TerminalFrame(
            rows: 1,
            columns: 20
        )

        frame.write(
            "abcdefghijklmnopqrst",
            in: TerminalRegion(
                rows: 1,
                columns: 20
            )
        )
        frame.write(
            "TOP",
            in: TerminalRegion(
                leading: 5,
                rows: 1,
                columns: 5
            ),
            zIndex: .overlay
        )
        frame.write(
            "late",
            in: TerminalRegion(
                leading: 6,
                rows: 1,
                columns: 4
            )
        )

        let resolved = frame.resolvedSpans(
            inRow: 0
        )

        guard resolved == [
            TerminalFrameSpan(
                row: 0,
                leading: 0,
                columns: 5,
                content: "abcde"
            ),
            TerminalFrameSpan(
                row: 0,
                leading: 5,
                columns: 5,
                content: "TOP  "
            ),
            TerminalFrameSpan(
                row: 0,
                leading: 10,
                columns: 10,
                content: "klmnopqrst"
            ),
        ] else {
            throw Failure.unexpectedFrameComposition
        }

        guard resolved.allSatisfy({
            TerminalDisplay.width(
                of: $0.content
            ) == $0.columns
        }) else {
            throw Failure.unexpectedFrameCompositionWidth
        }

        for pair in zip(
            resolved,
            resolved.dropFirst()
        ) {
            guard pair.0.leading + pair.0.columns
                <= pair.1.leading else {
                throw Failure.unexpectedFrameComposition
            }
        }

        var borderFrame = TerminalFrame(
            rows: 1,
            columns: 8
        )
        let border = TerminalStyle.dim.apply(
            "│"
        )
            + String(
                repeating: " ",
                count: 6
            )
            + TerminalStyle.dim.apply(
                "│"
            )

        borderFrame.write(
            border,
            in: TerminalRegion(
                rows: 1,
                columns: 8
            ),
            zIndex: .overlay
        )
        borderFrame.write(
            "content",
            in: TerminalRegion(
                leading: 2,
                rows: 1,
                columns: 4
            ),
            zIndex: .overlay
        )

        let borderResolved = borderFrame.resolvedSpans(
            inRow: 0
        )

        guard borderResolved.count == 3,
              borderResolved[0].leading == 0,
              borderResolved[0].columns == 2,
              stripANSI(
                borderResolved[0].content
              ) == "│ ",
              borderResolved[1].leading == 2,
              borderResolved[1].columns == 4,
              stripANSI(
                borderResolved[1].content
              ) == "cont",
              borderResolved[2].leading == 6,
              borderResolved[2].columns == 2,
              stripANSI(
                borderResolved[2].content
              ) == " │" else {
            throw Failure.unexpectedFrameCompositionBorder
        }

        guard borderResolved.allSatisfy({
            TerminalDisplay.width(
                of: $0.content
            ) == $0.columns
        }) else {
            throw Failure.unexpectedFrameCompositionWidth
        }

        let resolvedFrame = borderFrame.resolved()

        guard resolvedFrame.spans(
            inRow: 0
        ) == borderResolved,
        resolvedFrame.spans(
            inRow: 1
        ).isEmpty else {
            throw Failure.unexpectedFrameComposition
        }
    }

    private static func runLayoutProbe() throws {
        let horizontal = TerminalLayout.horizontal(
            in: TerminalRegion(
                rows: 20,
                columns: 100
            ),
            [
                .fixed(20),
                .flex(1),
                .fixed(10),
            ],
            spacing: 2
        )

        guard horizontal.map(
            \.columns
        ) == [
            20,
            66,
            10,
        ] else {
            throw Failure.unexpectedHorizontalLayout
        }

        let vertical = TerminalLayout.vertical(
            in: TerminalRegion(
                rows: 20,
                columns: 80
            ),
            [
                .fixed(3),
                .flex(1),
                .fixed(2),
            ],
            spacing: 1
        )

        guard vertical.map(
            \.rows
        ) == [
            3,
            13,
            2,
        ] else {
            throw Failure.unexpectedVerticalLayout
        }
    }
}
