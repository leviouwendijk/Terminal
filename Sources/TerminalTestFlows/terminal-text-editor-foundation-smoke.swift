import Terminal

enum TerminalTextEditorFoundationSmoke {
    enum Failure:
        Error
    {
        case unexpectedMode
        case unexpectedInsertion
        case unexpectedMotion
        case unexpectedSelection
        case unexpectedCopy
        case unexpectedDelete
        case unexpectedPaste
        case unexpectedRender
    }

    static func run() throws {
        try runModeAndInsertionProbe()
        try runMotionProbe()
        try runVisualProbe()
        try runPasteProbe()
        try runRenderProbe()
    }

    private static func runModeAndInsertionProbe() throws {
        var editor = TerminalTextEditor(
            text: "abc",
            cursorOffset: 1
        )

        guard editor.handle(
            .char("i")
        ) == .changed,
        editor.mode == .insert else {
            throw Failure.unexpectedMode
        }

        _ = editor.handle(
            .char("X")
        )
        _ = editor.handle(
            .enter
        )
        _ = editor.handle(
            .char("Y")
        )

        guard editor.buffer.text == "aX\nYbc" else {
            throw Failure.unexpectedInsertion
        }

        guard editor.handle(
            .escape
        ) == .changed,
        editor.mode == .normal else {
            throw Failure.unexpectedMode
        }
    }

    private static func runMotionProbe() throws {
        var editor = TerminalTextEditor(
            text: "abc\ndef\nghi",
            cursorOffset: 1
        )

        _ = editor.handle(
            .char("j")
        )

        guard editor.buffer.cursorPosition == TerminalTextPosition(
            row: 1,
            column: 1
        ) else {
            throw Failure.unexpectedMotion
        }

        _ = editor.handle(
            .char("G")
        )

        guard editor.buffer.cursorOffset == editor.buffer.characterCount else {
            throw Failure.unexpectedMotion
        }

        _ = editor.handle(
            .char("g")
        )
        _ = editor.handle(
            .char("g")
        )

        guard editor.buffer.cursorOffset == 0 else {
            throw Failure.unexpectedMotion
        }
    }

    private static func runVisualProbe() throws {
        var editor = TerminalTextEditor(
            text: "abcd",
            cursorOffset: 0
        )

        _ = editor.handle(
            .char("v")
        )
        _ = editor.handle(
            .char("l")
        )

        guard editor.mode == .visual,
              editor.selectionRange == 0..<2 else {
            throw Failure.unexpectedSelection
        }

        guard editor.handle(
            .char("y")
        ) == .copied(
            "ab"
        ),
        editor.mode == .normal,
        editor.selectionRange == nil else {
            throw Failure.unexpectedCopy
        }

        editor.replace(
            with: "abcd",
            cursorOffset: 0
        )
        _ = editor.handle(
            .char("v")
        )
        _ = editor.handle(
            .char("l")
        )
        _ = editor.handle(
            .char("d")
        )

        guard editor.buffer.text == "cd",
              editor.buffer.cursorOffset == 0,
              editor.mode == .normal else {
            throw Failure.unexpectedDelete
        }
    }

    private static func runPasteProbe() throws {
        var editor = TerminalTextEditor(
            text: "tail",
            cursorOffset: 0,
            mode: .insert
        )

        guard editor.handle(
            .paste(
                "one\r\ntwo\r"
            )
        ) == .changed,
        editor.buffer.text == "one\ntwo\ntail" else {
            throw Failure.unexpectedPaste
        }
    }

    private static func runRenderProbe() throws {
        var editor = TerminalTextEditor(
            text: "abcdef",
            cursorOffset: 4,
            visibleRows: 2
        )
        var frame = TerminalFrame(
            rows: 2,
            columns: 3
        )

        editor.render(
            into: &frame,
            in: TerminalRegion(
                rows: 2,
                columns: 3
            )
        )

        guard frame.spans(
            inRow: 0
        ).first?.content == "abc",
        frame.spans(
            inRow: 1
        ).first?.content == "def",
        frame.cursor == TerminalFrameCursor(
            row: 1,
            column: 1
        ) else {
            throw Failure.unexpectedRender
        }
    }
}
