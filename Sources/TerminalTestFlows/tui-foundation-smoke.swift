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
        case unexpectedHorizontalLayout
        case unexpectedVerticalLayout
    }

    static func run() throws {
        try runViewportProbe()
        try runTextInputProbe()
        try runDisplayProbe()
        try runBlockWrapProbe()
        try runDifferenceEndOfFileProbe()
        try runFrameProbe()
        try TerminalControlFoundationSmoke.run()
        try TerminalOverlayFoundationSmoke.run()
        try TerminalInteractionFoundationSmoke.run()
        try TerminalInputFoundationSmoke.run()
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
