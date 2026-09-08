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
        case unexpectedClipboard
        case unexpectedYankPresentation
        case unexpectedRegister
        case unexpectedDelete
        case unexpectedPaste
        case unexpectedRender
        case unexpectedReflow
        case unexpectedReplacementRender
        case unexpectedScrollHint
    }

    static func run() throws {
        try runModeAndInsertionProbe()
        try runNormalEditCommandProbe()
        try runCursorShapeProbe()
        try runMotionProbe()
        try runCountedMotionProbe()
        try runOperatorProbe()
        try runChangeOperatorProbe()
        try runOperatorAliasProbe()
        try runReplaceCharacterProbe()
        try runReplaceModeProbe()
        try runJoinAndCaseProbe()
        try runShiftOperatorProbe()
        try runYankPresentationProbe()
        try runVisualProbe()
        try runLinewiseVisualProbe()
        try runVisualChangeProbe()
        try runBlockInsertSessionProbe()
        try runBlockVisualProbe()
        try runRegisterProbe()
        try runRegisterPasteProbe()
        try runPasteProbe()
        try runRenderProbe()
        try runScrollHintProbe()
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

    private static func runNormalEditCommandProbe() throws {
        var editor = TerminalTextEditor(
            text: "    alpha\nbeta",
            cursorOffset: 7,
            clipboard: .disabled
        )

        guard editor.handle(
            .char("I")
        ) == .changed,
        editor.mode == .insert,
        editor.buffer.cursorOffset == 4 else {
            throw Failure.unexpectedMode
        }

        _ = editor.handle(
            .char("X")
        )

        guard editor.buffer.text
            == "    Xalpha\nbeta" else {
            throw Failure.unexpectedInsertion
        }

        _ = editor.handle(
            .escape
        )
        editor.replace(
            with: "alpha\nbeta",
            cursorOffset: 1
        )

        guard editor.handle(
            .char("A")
        ) == .changed,
        editor.mode == .insert,
        editor.buffer.cursorOffset == 5 else {
            throw Failure.unexpectedMode
        }

        _ = editor.handle(
            .char("X")
        )

        guard editor.buffer.text
            == "alphaX\nbeta" else {
            throw Failure.unexpectedInsertion
        }

        _ = editor.handle(
            .escape
        )
        editor.replace(
            with: "alpha\nbeta",
            cursorOffset: 1
        )

        guard editor.handle(
            .char("o")
        ) == .changed,
        editor.mode == .insert,
        editor.buffer.text == "alpha\n\nbeta",
        editor.buffer.cursorOffset == 6 else {
            throw Failure.unexpectedInsertion
        }

        _ = editor.handle(
            .char("X")
        )

        guard editor.buffer.text
            == "alpha\nX\nbeta" else {
            throw Failure.unexpectedInsertion
        }

        _ = editor.handle(
            .escape
        )
        editor.replace(
            with: "alpha\nbeta",
            cursorOffset: 7
        )

        guard editor.handle(
            .char("O")
        ) == .changed,
        editor.mode == .insert,
        editor.buffer.text == "alpha\n\nbeta",
        editor.buffer.cursorOffset == 6 else {
            throw Failure.unexpectedInsertion
        }

        _ = editor.handle(
            .char("X")
        )

        guard editor.buffer.text
            == "alpha\nX\nbeta" else {
            throw Failure.unexpectedInsertion
        }

        _ = editor.handle(
            .escape
        )
        editor.replace(
            with: "alpha",
            cursorOffset: 2
        )

        guard editor.handle(
            .char("o")
        ) == .changed,
        editor.buffer.text == "alpha\n",
        editor.buffer.cursorOffset == 6 else {
            throw Failure.unexpectedInsertion
        }
    }

    private static func runCursorShapeProbe() throws {
        var editor = TerminalTextEditor(
            text: "abc",
            cursorOffset: 1,
            visibleRows: 1,
            clipboard: .disabled
        )

        _ = editor.handle(
            .char("i")
        )

        var insertFrame = TerminalFrame(
            rows: 1,
            columns: 3
        )

        editor.render(
            into: &insertFrame,
            in: TerminalRegion(
                rows: 1,
                columns: 3
            )
        )

        guard insertFrame.cursor == TerminalFrameCursor(
            row: 0,
            column: 1,
            shape: .bar
        ) else {
            throw Failure.unexpectedRender
        }

        _ = editor.handle(
            .escape
        )

        var normalFrame = TerminalFrame(
            rows: 1,
            columns: 3
        )

        editor.render(
            into: &normalFrame,
            in: TerminalRegion(
                rows: 1,
                columns: 3
            )
        )

        guard normalFrame.cursor == TerminalFrameCursor(
            row: 0,
            column: 1,
            shape: .block
        ) else {
            throw Failure.unexpectedRender
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

    private static func runCountedMotionProbe() throws {
        var editor = TerminalTextEditor(
            text:
                (0...30)
                    .map {
                        "row \($0)"
                    }
                    .joined(
                        separator: "\n"
                    ),
            cursorOffset: 0
        )

        _ = editor.handle(
            .char("2")
        )
        _ = editor.handle(
            .char("3")
        )
        _ = editor.handle(
            .char("j")
        )

        guard editor.buffer.cursorPosition == TerminalTextPosition(
            row: 23,
            column: 0
        ) else {
            throw Failure.unexpectedMotion
        }
    }

    private static func runOperatorProbe() throws {
        var editor = TerminalTextEditor(
            text: "alpha\nbeta\ngamma",
            cursorOffset: 0,
            clipboard: .disabled
        )

        _ = editor.handle(
            .char("d")
        )
        _ = editor.handle(
            .char("d")
        )

        guard editor.buffer.text == "beta\ngamma",
              editor.buffer.cursorOffset == 0 else {
            throw Failure.unexpectedDelete
        }

        editor.replace(
            with: "one\ntwo\nthree\nfour",
            cursorOffset: 0
        )
        _ = editor.handle(
            .char("3")
        )
        _ = editor.handle(
            .char("d")
        )
        _ = editor.handle(
            .char("d")
        )

        guard editor.buffer.text == "four",
              editor.buffer.cursorOffset == 0 else {
            throw Failure.unexpectedDelete
        }

        editor.replace(
            with: "one two three four",
            cursorOffset: 0
        )
        _ = editor.handle(
            .char("d")
        )
        _ = editor.handle(
            .char("3")
        )
        _ = editor.handle(
            .char("w")
        )

        guard editor.buffer.text == "four",
              editor.buffer.cursorOffset == 0 else {
            throw Failure.unexpectedDelete
        }

        editor.replace(
            with: "one two three four five six seven",
            cursorOffset: 0
        )
        _ = editor.handle(
            .char("3")
        )
        _ = editor.handle(
            .char("d")
        )
        _ = editor.handle(
            .char("2")
        )
        _ = editor.handle(
            .char("w")
        )

        guard editor.buffer.text == "seven",
              editor.buffer.cursorOffset == 0 else {
            throw Failure.unexpectedDelete
        }

        editor.replace(
            with: "one\ntwo\nthree\nfour",
            cursorOffset: 0
        )
        _ = editor.handle(
            .char("d")
        )
        _ = editor.handle(
            .char("2")
        )
        _ = editor.handle(
            .char("j")
        )

        guard editor.buffer.text == "four",
              editor.buffer.cursorOffset == 0 else {
            throw Failure.unexpectedDelete
        }

        editor.replace(
            with: "alpha\nbeta",
            cursorOffset: 0
        )
        _ = editor.handle(
            .char("y")
        )

        guard editor.handle(
            .char("y")
        ) == .copied(
            "alpha\n"
        ),
        editor.buffer.text == "alpha\nbeta",
        editor.buffer.cursorOffset == 0 else {
            throw Failure.unexpectedCopy
        }

        _ = editor.handle(
            .char("y")
        )

        guard editor.handle(
            .char("w")
        ) == .copied(
            "alpha\n"
        ),
        editor.buffer.text == "alpha\nbeta" else {
            throw Failure.unexpectedCopy
        }
    }

    private static func runChangeOperatorProbe() throws {
        var editor = TerminalTextEditor(
            text: "alpha beta",
            cursorOffset: 0,
            clipboard: .disabled
        )

        guard editor.handle(
            .char("c")
        ) == nil,
        editor.handle(
            .char("w")
        ) == .changed,
        editor.mode == .insert,
        editor.buffer.text == " beta",
        editor.buffer.cursorOffset == 0,
        editor.registers.unnamed == .character(
            "alpha"
        ) else {
            throw Failure.unexpectedDelete
        }

        _ = editor.handle(
            .char("X")
        )

        guard editor.buffer.text == "X beta" else {
            throw Failure.unexpectedInsertion
        }

        _ = editor.handle(
            .escape
        )
        editor.replace(
            with: "one two three",
            cursorOffset: 0
        )

        _ = editor.handle(
            .char("c")
        )
        _ = editor.handle(
            .char("2")
        )

        guard editor.handle(
            .char("w")
        ) == .changed,
        editor.mode == .insert,
        editor.buffer.text == " three",
        editor.registers.unnamed == .character(
            "one two"
        ) else {
            throw Failure.unexpectedDelete
        }

        _ = editor.handle(
            .escape
        )
        editor.replace(
            with: "alpha\nbeta\ngamma",
            cursorOffset: 0
        )

        _ = editor.handle(
            .char("2")
        )
        _ = editor.handle(
            .char("c")
        )

        guard editor.handle(
            .char("c")
        ) == .changed,
        editor.mode == .insert,
        editor.buffer.text == "\ngamma",
        editor.buffer.cursorOffset == 0,
        editor.registers.unnamed == .line(
            "alpha\nbeta\n"
        ) else {
            throw Failure.unexpectedDelete
        }

        _ = editor.handle(
            .escape
        )
        editor.replace(
            with: "alpha beta\ngamma",
            cursorOffset: 6
        )

        _ = editor.handle(
            .char("c")
        )

        guard editor.handle(
            .char("$")
        ) == .changed,
        editor.mode == .insert,
        editor.buffer.text == "alpha \ngamma",
        editor.buffer.cursorOffset == 6,
        editor.registers.unnamed == .character(
            "beta"
        ) else {
            throw Failure.unexpectedDelete
        }

        _ = editor.handle(
            .escape
        )
        editor.replace(
            with: "",
            cursorOffset: 0
        )

        _ = editor.handle(
            .char("c")
        )

        guard editor.handle(
            .char("c")
        ) == .changed,
        editor.mode == .insert,
        editor.buffer.text.isEmpty,
        editor.buffer.cursorOffset == 0,
        editor.registers.unnamed == .line(
            ""
        ) else {
            throw Failure.unexpectedMode
        }
    }

    private static func runOperatorAliasProbe() throws {
        var editor = TerminalTextEditor(
            text: "alpha beta\ngamma",
            cursorOffset: 6,
            clipboard: .disabled
        )

        guard editor.handle(
            .char("D")
        ) == .changed,
        editor.mode == .normal,
        editor.buffer.text == "alpha \ngamma",
        editor.buffer.cursorOffset == 6,
        editor.registers.unnamed == .character(
            "beta"
        ) else {
            throw Failure.unexpectedDelete
        }

        editor.replace(
            with: "alpha beta\ngamma delta\nomega",
            cursorOffset: 6
        )
        _ = editor.handle(
            .char("2")
        )

        guard editor.handle(
            .char("D")
        ) == .changed,
        editor.mode == .normal,
        editor.buffer.text == "alpha \nomega",
        editor.buffer.cursorOffset == 6,
        editor.registers.unnamed == .character(
            "beta\ngamma delta"
        ) else {
            throw Failure.unexpectedDelete
        }

        editor.replace(
            with: "alpha beta\ngamma delta\nomega",
            cursorOffset: 6
        )
        _ = editor.handle(
            .char("2")
        )

        guard editor.handle(
            .char("C")
        ) == .changed,
        editor.mode == .insert,
        editor.buffer.text == "alpha \nomega",
        editor.buffer.cursorOffset == 6,
        editor.registers.unnamed == .character(
            "beta\ngamma delta"
        ) else {
            throw Failure.unexpectedDelete
        }

        _ = editor.handle(
            .char("X")
        )

        guard editor.buffer.text == "alpha X\nomega" else {
            throw Failure.unexpectedInsertion
        }

        _ = editor.handle(
            .escape
        )
        editor.replace(
            with: "alpha\nbeta\ngamma",
            cursorOffset: 1
        )
        _ = editor.handle(
            .char("2")
        )

        guard editor.handle(
            .char("S")
        ) == .changed,
        editor.mode == .insert,
        editor.buffer.text == "\ngamma",
        editor.buffer.cursorOffset == 0,
        editor.registers.unnamed == .line(
            "alpha\nbeta\n"
        ) else {
            throw Failure.unexpectedDelete
        }

        _ = editor.handle(
            .escape
        )
        editor.replace(
            with: "abcdef\nx",
            cursorOffset: 2
        )
        _ = editor.handle(
            .char("3")
        )

        guard editor.handle(
            .char("s")
        ) == .changed,
        editor.mode == .insert,
        editor.buffer.text == "abf\nx",
        editor.buffer.cursorOffset == 2,
        editor.registers.unnamed == .character(
            "cde"
        ) else {
            throw Failure.unexpectedDelete
        }

        _ = editor.handle(
            .escape
        )
        editor.replace(
            with: "abc\ndef",
            cursorOffset: 1
        )
        _ = editor.handle(
            .char("5")
        )

        guard editor.handle(
            .char("s")
        ) == .changed,
        editor.mode == .insert,
        editor.buffer.text == "a\ndef",
        editor.buffer.cursorOffset == 1,
        editor.registers.unnamed == .character(
            "bc"
        ) else {
            throw Failure.unexpectedDelete
        }
    }

    private static func runReplaceCharacterProbe() throws {
        var editor = TerminalTextEditor(
            text: "abcdef\nxyz",
            cursorOffset: 1,
            clipboard: .disabled
        )

        guard editor.handle(
            .char("r")
        ) == nil,
        editor.handle(
            .char("X")
        ) == .changed,
        editor.mode == .normal,
        editor.buffer.text == "aXcdef\nxyz",
        editor.buffer.cursorOffset == 1,
        editor.registers.unnamed == nil else {
            throw Failure.unexpectedReplacementRender
        }

        editor.replace(
            with: "abcdef\nxyz",
            cursorOffset: 2
        )
        _ = editor.handle(
            .char("3")
        )
        _ = editor.handle(
            .char("r")
        )

        guard editor.handle(
            .char("Z")
        ) == .changed,
        editor.buffer.text == "abZZZf\nxyz",
        editor.buffer.cursorOffset == 4 else {
            throw Failure.unexpectedReplacementRender
        }

        editor.replace(
            with: "abc\ndef",
            cursorOffset: 1
        )
        _ = editor.handle(
            .char("5")
        )
        _ = editor.handle(
            .char("r")
        )

        guard editor.handle(
            .char("Q")
        ) == nil,
        editor.buffer.text == "abc\ndef",
        editor.buffer.cursorOffset == 1,
        editor.mode == .normal else {
            throw Failure.unexpectedReplacementRender
        }

        editor.replace(
            with: "abc",
            cursorOffset: 1
        )
        _ = editor.handle(
            .char("r")
        )

        guard editor.handle(
            .enter
        ) == .changed,
        editor.buffer.text == "a\nc",
        editor.buffer.cursorOffset == 1,
        editor.mode == .normal else {
            throw Failure.unexpectedReplacementRender
        }

        editor.replace(
            with: "abc",
            cursorOffset: 1
        )
        _ = editor.handle(
            .char("r")
        )

        guard editor.handle(
            .escape
        ) == nil,
        editor.buffer.text == "abc",
        editor.buffer.cursorOffset == 1,
        editor.mode == .normal else {
            throw Failure.unexpectedMode
        }
    }

    private static func runReplaceModeProbe() throws {
        var editor = TerminalTextEditor(
            text: "abcdef",
            cursorOffset: 1,
            visibleRows: 1,
            clipboard: .disabled
        )

        guard editor.handle(
            .char("R")
        ) == .changed,
        editor.mode == .replace,
        editor.replaceSession
            == TerminalReplaceSession(
                startOffset: 1
            ) else {
            throw Failure.unexpectedMode
        }

        _ = editor.handle(
            .char("X")
        )
        _ = editor.handle(
            .char("Y")
        )

        guard editor.buffer.text == "aXYdef",
        editor.buffer.cursorOffset == 3,
        editor.replaceSession?.steps.count == 2 else {
            throw Failure.unexpectedReplacementRender
        }

        guard editor.handle(
            .backspace
        ) == .changed,
        editor.buffer.text == "aXcdef",
        editor.buffer.cursorOffset == 2 else {
            throw Failure.unexpectedReplacementRender
        }

        _ = editor.handle(
            .char("Z")
        )

        guard editor.buffer.text == "aXZdef",
        editor.buffer.cursorOffset == 3 else {
            throw Failure.unexpectedReplacementRender
        }

        var replaceFrame = TerminalFrame(
            rows: 1,
            columns: 6
        )

        editor.render(
            into: &replaceFrame,
            in: TerminalRegion(
                rows: 1,
                columns: 6
            )
        )

        guard replaceFrame.cursor?.shape == .underline else {
            throw Failure.unexpectedRender
        }

        _ = editor.handle(
            .escape
        )

        guard editor.mode == .normal,
        editor.replaceSession == nil else {
            throw Failure.unexpectedMode
        }

        editor.replace(
            with: "abc\ndef",
            cursorOffset: 3
        )
        _ = editor.handle(
            .char("R")
        )
        _ = editor.handle(
            .char("X")
        )
        _ = editor.handle(
            .char("Y")
        )

        guard editor.buffer.text == "abcXY\ndef",
        editor.buffer.cursorOffset == 5 else {
            throw Failure.unexpectedReplacementRender
        }

        guard editor.handle(
            .backspace
        ) == .changed,
        editor.buffer.text == "abcX\ndef",
        editor.buffer.cursorOffset == 4 else {
            throw Failure.unexpectedReplacementRender
        }

        _ = editor.handle(
            .escape
        )
        editor.replace(
            with: "abcd",
            cursorOffset: 2
        )
        _ = editor.handle(
            .char("R")
        )

        guard editor.handle(
            .enter
        ) == .changed,
        editor.buffer.text == "ab\ncd",
        editor.buffer.cursorOffset == 3 else {
            throw Failure.unexpectedReplacementRender
        }

        guard editor.handle(
            .backspace
        ) == .changed,
        editor.buffer.text == "abcd",
        editor.buffer.cursorOffset == 2 else {
            throw Failure.unexpectedReplacementRender
        }

        _ = editor.handle(
            .escape
        )
        editor.replace(
            with: "abcdef",
            cursorOffset: 1
        )
        _ = editor.handle(
            .char("R")
        )

        guard editor.handle(
            .paste(
                "XY"
            )
        ) == .changed,
        editor.buffer.text == "aXYdef",
        editor.buffer.cursorOffset == 3 else {
            throw Failure.unexpectedPaste
        }

        _ = editor.handle(
            .left
        )

        guard editor.replaceSession?.steps.isEmpty == true,
        editor.buffer.cursorOffset == 2 else {
            throw Failure.unexpectedMotion
        }

        guard editor.handle(
            .backspace
        ) == nil,
        editor.buffer.text == "aXYdef" else {
            throw Failure.unexpectedReplacementRender
        }
    }

    private static func runJoinAndCaseProbe() throws {
        var editor = TerminalTextEditor(
            text: "alpha\n    beta\ngamma",
            cursorOffset: 1,
            clipboard: .disabled
        )

        guard editor.handle(
            .char("J")
        ) == .changed,
        editor.buffer.text == "alpha beta\ngamma",
        editor.buffer.cursorOffset == 5,
        editor.registers.unnamed == nil else {
            throw Failure.unexpectedReplacementRender
        }

        editor.replace(
            with: "alpha\n    beta\n  gamma",
            cursorOffset: 1
        )
        _ = editor.handle(
            .char("3")
        )

        guard editor.handle(
            .char("J")
        ) == .changed,
        editor.buffer.text == "alpha beta gamma",
        editor.buffer.cursorOffset == 5 else {
            throw Failure.unexpectedReplacementRender
        }

        editor.replace(
            with: "aBcD\nef",
            cursorOffset: 0
        )
        _ = editor.handle(
            .char("4")
        )

        guard editor.handle(
            .char("~")
        ) == .changed,
        editor.buffer.text == "AbCd\nef",
        editor.buffer.cursorOffset == 3,
        editor.registers.unnamed == nil else {
            throw Failure.unexpectedReplacementRender
        }
    }

    private static func runShiftOperatorProbe() throws {
        let source =
            "alpha\n  beta\n    gamma\n\nomega"
        var editor = TerminalTextEditor(
            text: source,
            cursorOffset: 1,
            clipboard: .disabled
        )

        _ = editor.handle(
            .char(">")
        )

        guard editor.handle(
            .char(">")
        ) == .changed,
        editor.buffer.text
            == "    alpha\n  beta\n    gamma\n\nomega",
        editor.buffer.cursorOffset == 4,
        editor.registers.unnamed == nil else {
            throw Failure.unexpectedReplacementRender
        }

        editor.replace(
            with: source,
            cursorOffset: 1
        )
        _ = editor.handle(
            .char("3")
        )
        _ = editor.handle(
            .char(">")
        )

        guard editor.handle(
            .char(">")
        ) == .changed,
        editor.buffer.text
            == "    alpha\n      beta\n        gamma\n\nomega",
        editor.buffer.cursorOffset == 4,
        editor.registers.unnamed == nil else {
            throw Failure.unexpectedReplacementRender
        }

        _ = editor.handle(
            .char("3")
        )
        _ = editor.handle(
            .char("<")
        )

        guard editor.handle(
            .char("<")
        ) == .changed,
        editor.buffer.text == source,
        editor.buffer.cursorOffset == 0,
        editor.registers.unnamed == nil else {
            throw Failure.unexpectedReplacementRender
        }

        editor.replace(
            with: source,
            cursorOffset: 1
        )
        _ = editor.handle(
            .char(">")
        )

        guard editor.handle(
            .char("j")
        ) == .changed,
        editor.buffer.text
            == "    alpha\n      beta\n    gamma\n\nomega",
        editor.buffer.cursorOffset == 4 else {
            throw Failure.unexpectedReplacementRender
        }

        editor.replace(
            with: source,
            cursorOffset: 8
        )
        _ = editor.handle(
            .char("<")
        )

        guard editor.handle(
            .char("k")
        ) == .changed,
        editor.buffer.text
            == "alpha\nbeta\n    gamma\n\nomega",
        editor.buffer.cursorOffset == 0 else {
            throw Failure.unexpectedReplacementRender
        }

        editor.replace(
            with: "alpha\n\nbeta",
            cursorOffset: 1
        )
        _ = editor.handle(
            .char("3")
        )
        _ = editor.handle(
            .char(">")
        )

        guard editor.handle(
            .char(">")
        ) == .changed,
        editor.buffer.text
            == "    alpha\n\n    beta" else {
            throw Failure.unexpectedReplacementRender
        }

        var narrow = TerminalTextEditor(
            text: "alpha",
            cursorOffset: 1,
            shiftWidth: 2,
            clipboard: .disabled
        )
        _ = narrow.handle(
            .char(">")
        )

        guard narrow.handle(
            .char(">")
        ) == .changed,
        narrow.buffer.text == "  alpha",
        narrow.buffer.cursorOffset == 2 else {
            throw Failure.unexpectedReplacementRender
        }
    }

    private static func runYankPresentationProbe() throws {
        let clipboard = TerminalClipboardDestination.named(
            "terminal-text-editor-foundation-smoke"
        )
        var editor = TerminalTextEditor(
            text: "alpha\nbeta",
            cursorOffset: 0,
            visibleRows: 2,
            clipboard: clipboard
        )

        _ = editor.handle(
            .char("y")
        )

        guard editor.handle(
            .char("y")
        ) == .copied(
            "alpha\n"
        ) else {
            throw Failure.unexpectedCopy
        }

        guard clipboard.read() == "alpha\n" else {
            throw Failure.unexpectedClipboard
        }

        guard let presentation = editor.yankPresentation,
              presentation.sourceRange == 0..<6,
              editor.nextPresentationDeadlineNanoseconds
                == presentation.expiresAtNanoseconds else {
            throw Failure.unexpectedYankPresentation
        }

        let activeTime = presentation.expiresAtNanoseconds - 1
        var activeFrame = TerminalFrame(
            rows: 2,
            columns: 8
        )

        editor.render(
            into: &activeFrame,
            in: TerminalRegion(
                rows: 2,
                columns: 8
            ),
            atNanoseconds: activeTime
        )

        let activeContent = activeFrame.spans(
            inRow: 0
        )
            .map(\.content)
            .joined()

        guard activeContent.contains(
            ANSIColor.brightYellowBackground.rawValue
        ),
        activeContent.contains(
            ANSIColor.black.rawValue
        ) else {
            throw Failure.unexpectedYankPresentation
        }

        var expiredFrame = TerminalFrame(
            rows: 2,
            columns: 8
        )

        editor.render(
            into: &expiredFrame,
            in: TerminalRegion(
                rows: 2,
                columns: 8
            ),
            atNanoseconds:
                presentation.expiresAtNanoseconds
        )

        let expiredContent = expiredFrame.spans(
            inRow: 0
        )
            .map(\.content)
            .joined()

        guard !expiredContent.contains(
            ANSIColor.brightYellowBackground.rawValue
        ),
        editor.yankPresentation == nil else {
            throw Failure.unexpectedYankPresentation
        }
    }

    private static func runVisualProbe() throws {
        var editor = TerminalTextEditor(
            text: "abcd",
            cursorOffset: 0,
            clipboard: .disabled
        )

        _ = editor.handle(
            .char("v")
        )
        _ = editor.handle(
            .char("l")
        )

        guard editor.mode == .visual,
              editor.selection == TerminalSelection(
                anchor: 0,
                cursor: 1,
                kind: .character
              ),
              editor.selectionRange == 0..<2 else {
            throw Failure.unexpectedSelection
        }

        guard editor.handle(
            .char("y")
        ) == .copied(
            "ab"
        ),
        editor.mode == .normal,
        editor.selection == nil,
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

    private static func runLinewiseVisualProbe() throws {
        var editor = TerminalTextEditor(
            text: "alpha\nbeta\ngamma",
            cursorOffset: 7,
            clipboard: .disabled
        )

        guard editor.handle(
            .char("V")
        ) == .changed,
        editor.mode == .visual,
        editor.selection == TerminalSelection(
            anchor: 7,
            cursor: 7,
            kind: .line
        ),
        editor.selectionRange == 6..<11 else {
            throw Failure.unexpectedSelection
        }

        _ = editor.handle(
            .char("j")
        )

        guard editor.selection?.kind == .line,
              editor.selectionRange == 6..<16 else {
            throw Failure.unexpectedSelection
        }

        guard editor.handle(
            .char("y")
        ) == .copied(
            "beta\ngamma"
        ),
        editor.mode == .normal,
        editor.selection == nil else {
            throw Failure.unexpectedCopy
        }

        editor.replace(
            with: "alpha\nbeta\ngamma",
            cursorOffset: 7
        )

        _ = editor.handle(
            .char("V")
        )
        _ = editor.handle(
            .char("j")
        )
        _ = editor.handle(
            .char("d")
        )

        guard editor.buffer.text == "alpha\n",
              editor.buffer.cursorOffset == 6,
              editor.mode == .normal,
              editor.selection == nil else {
            throw Failure.unexpectedDelete
        }
    }

    private static func runVisualChangeProbe() throws {
        var editor = TerminalTextEditor(
            text: "abcd",
            cursorOffset: 0,
            clipboard: .disabled
        )

        _ = editor.handle(
            .char("v")
        )
        _ = editor.handle(
            .char("l")
        )

        guard editor.handle(
            .char("c")
        ) == .changed,
        editor.mode == .insert,
        editor.selection == nil,
        editor.buffer.text == "cd",
        editor.buffer.cursorOffset == 0,
        editor.registers.unnamed == .character(
            "ab"
        ) else {
            throw Failure.unexpectedDelete
        }

        _ = editor.handle(
            .char("X")
        )

        guard editor.buffer.text == "Xcd" else {
            throw Failure.unexpectedInsertion
        }

        _ = editor.handle(
            .escape
        )
        editor.replace(
            with: "alpha\nbeta\ngamma",
            cursorOffset: 0
        )

        _ = editor.handle(
            .char("V")
        )
        _ = editor.handle(
            .char("j")
        )

        guard editor.handle(
            .char("c")
        ) == .changed,
        editor.mode == .insert,
        editor.selection == nil,
        editor.buffer.text == "\ngamma",
        editor.buffer.cursorOffset == 0,
        editor.registers.unnamed == .line(
            "alpha\nbeta\n"
        ) else {
            throw Failure.unexpectedDelete
        }

        _ = editor.handle(
            .escape
        )
    }

    private static func runBlockInsertSessionProbe() throws {
        var editor = TerminalTextEditor(
            text: "abcd\nx\nwxyz",
            cursorOffset: 1,
            clipboard: .disabled
        )

        _ = editor.handle(
            .control("V")
        )
        _ = editor.handle(
            .char("j")
        )
        _ = editor.handle(
            .char("j")
        )

        guard editor.handle(
            .char("I")
        ) == .changed,
        editor.mode == .insert,
        editor.selection == nil,
        editor.blockInsertSession
            == TerminalBlockInsertSession(
                operation: .insertBefore,
                rows: [
                    0,
                    1,
                    2,
                ],
                insertionColumn: 1,
                primaryRow: 0
            ) else {
            throw Failure.unexpectedMode
        }

        _ = editor.handle(
            .char("Q")
        )

        guard editor.buffer.text
            == "aQbcd\nx\nwxyz" else {
            throw Failure.unexpectedInsertion
        }

        _ = editor.handle(
            .escape
        )

        guard editor.buffer.text
            == "aQbcd\nxQ\nwQxyz",
        editor.mode == .normal,
        editor.blockInsertSession == nil else {
            throw Failure.unexpectedInsertion
        }

        editor.replace(
            with: "abcd\nx\nwxyz",
            cursorOffset: 1
        )
        _ = editor.handle(
            .control("V")
        )
        _ = editor.handle(
            .char("j")
        )
        _ = editor.handle(
            .char("j")
        )
        _ = editor.handle(
            .char("A")
        )
        _ = editor.handle(
            .char("Q")
        )
        _ = editor.handle(
            .escape
        )

        guard editor.buffer.text
            == "abQcd\nx Q\nwxQyz" else {
            throw Failure.unexpectedInsertion
        }

        editor.replace(
            with: "abcd\nx\nwxyz",
            cursorOffset: 1
        )
        _ = editor.handle(
            .control("V")
        )
        _ = editor.handle(
            .char("j")
        )
        _ = editor.handle(
            .char("j")
        )

        guard editor.handle(
            .char("c")
        ) == .changed,
        editor.mode == .insert,
        editor.registers.unnamed
            == .block(
                [
                    "b",
                    "",
                    "x",
                ]
            ),
        editor.blockInsertSession?.operation
            == .change else {
            throw Failure.unexpectedRegister
        }

        _ = editor.handle(
            .char("Z")
        )
        _ = editor.handle(
            .escape
        )

        guard editor.buffer.text
            == "aZcd\nxZ\nwZyz",
        editor.blockInsertSession == nil else {
            throw Failure.unexpectedInsertion
        }

        editor.replace(
            with: "abcd\nx\nwxyz",
            cursorOffset: 1
        )
        _ = editor.handle(
            .control("V")
        )
        _ = editor.handle(
            .char("j")
        )
        _ = editor.handle(
            .char("j")
        )
        _ = editor.handle(
            .char("I")
        )
        _ = editor.handle(
            .char("Q")
        )
        _ = editor.handle(
            .char("R")
        )
        _ = editor.handle(
            .backspace
        )
        _ = editor.handle(
            .escape
        )

        guard editor.buffer.text
            == "aQbcd\nxQ\nwQxyz" else {
            throw Failure.unexpectedInsertion
        }

        editor.replace(
            with: "abcd\nx\nwxyz",
            cursorOffset: 1
        )
        _ = editor.handle(
            .control("V")
        )
        _ = editor.handle(
            .char("j")
        )
        _ = editor.handle(
            .char("j")
        )
        _ = editor.handle(
            .char("I")
        )
        _ = editor.handle(
            .paste(
                "XY"
            )
        )
        _ = editor.handle(
            .escape
        )

        guard editor.buffer.text
            == "aXYbcd\nxXY\nwXYxyz" else {
            throw Failure.unexpectedPaste
        }
    }

    private static func runBlockVisualProbe() throws {
        var editor = TerminalTextEditor(
            text: "a\tbc\nx\n😀xyz",
            cursorOffset: 1,
            visibleRows: 3,
            clipboard: .disabled
        )

        guard editor.handle(
            .control("V")
        ) == .changed,
        editor.mode == .visual,
        editor.selection?.kind == .block,
        editor.selection?.blockPreferredColumn == 1 else {
            throw Failure.unexpectedSelection
        }

        _ = editor.handle(
            .char("j")
        )
        _ = editor.handle(
            .char("j")
        )

        guard editor.buffer.cursorOffset == 7,
              editor.selection == TerminalSelection(
                anchor: 1,
                cursor: 7,
                kind: .block,
                blockPreferredColumn: 1
              ),
              editor.selectionRange == nil,
              case .block(let block) = editor.resolvedSelection,
              block.columns == 0..<4,
              block.rows == [
                TerminalResolvedBlockRow(
                    row: 0,
                    sourceRange: 0..<2
                ),
                TerminalResolvedBlockRow(
                    row: 1,
                    sourceRange: 5..<6
                ),
                TerminalResolvedBlockRow(
                    row: 2,
                    sourceRange: 7..<10
                ),
              ] else {
            throw Failure.unexpectedSelection
        }

        var selectionFrame = TerminalFrame(
            rows: 3,
            columns: 12
        )

        editor.render(
            into: &selectionFrame,
            in: TerminalRegion(
                rows: 3,
                columns: 12
            )
        )

        guard (0..<3).allSatisfy({ row in
            selectionFrame.spans(
                inRow: row
            )
                .map(\.content)
                .joined()
                .contains(
                    ANSIColor.inverse.rawValue
                )
        }) else {
            throw Failure.unexpectedRender
        }

        guard editor.handle(
            .char("y")
        ) == .copied(
            "a\t\nx\n😀xy"
        ),
        editor.mode == .normal,
        editor.selection == nil,
        editor.yankPresentation?.sourceRanges == [
            0..<2,
            5..<6,
            7..<10,
        ] else {
            throw Failure.unexpectedCopy
        }

        guard let presentation = editor.yankPresentation else {
            throw Failure.unexpectedYankPresentation
        }

        var yankFrame = TerminalFrame(
            rows: 3,
            columns: 12
        )

        editor.render(
            into: &yankFrame,
            in: TerminalRegion(
                rows: 3,
                columns: 12
            ),
            atNanoseconds:
                presentation.expiresAtNanoseconds - 1
        )

        guard (0..<3).allSatisfy({ row in
            yankFrame.spans(
                inRow: row
            )
                .map(\.content)
                .joined()
                .contains(
                    ANSIColor.brightYellowBackground.rawValue
                )
        }) else {
            throw Failure.unexpectedYankPresentation
        }

        editor.replace(
            with: "a\tbc\nx\n😀xyz",
            cursorOffset: 1
        )

        _ = editor.handle(
            .control("V")
        )
        _ = editor.handle(
            .char("j")
        )
        _ = editor.handle(
            .char("j")
        )
        _ = editor.handle(
            .char("d")
        )

        guard editor.buffer.text == "bc\n\nz",
              editor.buffer.cursorOffset == 0,
              editor.mode == .normal,
              editor.selection == nil else {
            throw Failure.unexpectedDelete
        }
    }

    private static func runRegisterProbe() throws {
        var editor = TerminalTextEditor(
            text: "alpha\nbeta",
            cursorOffset: 0,
            clipboard: .disabled
        )

        _ = editor.handle(
            .char("y")
        )
        _ = editor.handle(
            .char("y")
        )

        guard editor.registers.unnamed
            == .line(
                "alpha\n"
            ) else {
            throw Failure.unexpectedRegister
        }

        editor.replace(
            with: "alpha\nbeta",
            cursorOffset: 0
        )
        _ = editor.handle(
            .char("y")
        )
        _ = editor.handle(
            .char("w")
        )

        guard editor.registers.unnamed
            == .character(
                "alpha\n"
            ) else {
            throw Failure.unexpectedRegister
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
              editor.registers.unnamed
                == .character(
                    "ab"
                ) else {
            throw Failure.unexpectedRegister
        }

        editor.replace(
            with: "a\tbc\nx\n😀xyz",
            cursorOffset: 1
        )
        _ = editor.handle(
            .control("V")
        )
        _ = editor.handle(
            .char("j")
        )
        _ = editor.handle(
            .char("j")
        )
        _ = editor.handle(
            .char("y")
        )

        guard editor.registers.unnamed
            == .block(
                [
                    "a\t",
                    "x",
                    "😀xy",
                ]
            ) else {
            throw Failure.unexpectedRegister
        }
    }

    private static func runRegisterPasteProbe() throws {
        var editor = TerminalTextEditor(
            text: "abc",
            cursorOffset: 1,
            clipboard: .disabled,
            registers: TerminalRegisterBank(
                unnamed:
                    .character(
                        "XY"
                    )
            )
        )

        guard editor.handle(
            .char("p")
        ) == .changed,
        editor.buffer.text == "abXYc",
        editor.buffer.cursorOffset == 3 else {
            throw Failure.unexpectedPaste
        }

        editor.replace(
            with: "abc",
            cursorOffset: 1
        )

        guard editor.handle(
            .char("P")
        ) == .changed,
        editor.buffer.text == "aXYbc",
        editor.buffer.cursorOffset == 2 else {
            throw Failure.unexpectedPaste
        }

        editor.replace(
            with: "abc",
            cursorOffset: 1
        )
        _ = editor.handle(
            .char("3")
        )

        guard editor.handle(
            .char("p")
        ) == .changed,
        editor.buffer.text == "abXYXYXYc",
        editor.buffer.cursorOffset == 7 else {
            throw Failure.unexpectedPaste
        }

        editor = TerminalTextEditor(
            text: "one\ntwo",
            cursorOffset: 1,
            clipboard: .disabled,
            registers: TerminalRegisterBank(
                unnamed:
                    .line(
                        "alpha"
                    )
            )
        )

        guard editor.handle(
            .char("p")
        ) == .changed,
        editor.buffer.text == "one\nalpha\ntwo",
        editor.buffer.cursorOffset == 4 else {
            throw Failure.unexpectedPaste
        }

        editor.replace(
            with: "one\ntwo",
            cursorOffset: 1
        )

        guard editor.handle(
            .char("P")
        ) == .changed,
        editor.buffer.text == "alpha\none\ntwo",
        editor.buffer.cursorOffset == 0 else {
            throw Failure.unexpectedPaste
        }

        editor.replace(
            with: "one\ntwo",
            cursorOffset: 1
        )
        _ = editor.handle(
            .char("2")
        )

        guard editor.handle(
            .char("p")
        ) == .changed,
        editor.buffer.text == "one\nalpha\nalpha\ntwo",
        editor.buffer.cursorOffset == 4 else {
            throw Failure.unexpectedPaste
        }

        editor = TerminalTextEditor(
            text: "abcd\nx",
            cursorOffset: 3,
            clipboard: .disabled,
            registers: TerminalRegisterBank(
                unnamed:
                    .block(
                        [
                            "Q",
                            "Z",
                        ]
                    )
            )
        )

        guard editor.handle(
            .char("P")
        ) == .changed,
        editor.buffer.text == "abcQd\nx  Z",
        editor.buffer.cursorOffset == 3 else {
            throw Failure.unexpectedPaste
        }

        editor = TerminalTextEditor(
            text: "ab\ncd",
            cursorOffset: 0,
            clipboard: .disabled,
            registers: TerminalRegisterBank(
                unnamed:
                    .block(
                        [
                            "X",
                            "Y",
                        ]
                    )
            )
        )
        _ = editor.handle(
            .char("2")
        )

        guard editor.handle(
            .char("P")
        ) == .changed,
        editor.buffer.text == "XXab\nYYcd",
        editor.buffer.cursorOffset == 0 else {
            throw Failure.unexpectedPaste
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
            column: 1,
            shape: .block
        ) else {
            throw Failure.unexpectedRender
        }

        var repeatedFrame = TerminalFrame(
            rows: 2,
            columns: 3
        )

        editor.render(
            into: &repeatedFrame,
            in: TerminalRegion(
                rows: 2,
                columns: 3
            )
        )

        guard repeatedFrame.spans(
            inRow: 0
        ).first?.content == "abc",
        repeatedFrame.spans(
            inRow: 1
        ).first?.content == "def",
        repeatedFrame.cursor == TerminalFrameCursor(
            row: 1,
            column: 1,
            shape: .block
        ) else {
            throw Failure.unexpectedRender
        }

        var widerFrame = TerminalFrame(
            rows: 1,
            columns: 6
        )

        editor.render(
            into: &widerFrame,
            in: TerminalRegion(
                rows: 1,
                columns: 6
            )
        )

        guard widerFrame.spans(
            inRow: 0
        ).first?.content == "abcdef",
        widerFrame.cursor == TerminalFrameCursor(
            row: 0,
            column: 4,
            shape: .block
        ) else {
            throw Failure.unexpectedReflow
        }

        editor.replace(
            with: "xy"
        )

        var replacementFrame = TerminalFrame(
            rows: 1,
            columns: 6
        )

        editor.render(
            into: &replacementFrame,
            in: TerminalRegion(
                rows: 1,
                columns: 6
            )
        )

        guard replacementFrame.spans(
            inRow: 0
        ).first?.content == "xy",
        replacementFrame.cursor == TerminalFrameCursor(
            row: 0,
            column: 2,
            shape: .block
        ) else {
            throw Failure.unexpectedReplacementRender
        }
    }

    private static func runScrollHintProbe() throws {
        var editor = TerminalTextEditor(
            text: "one\ntwo\nthree\nfour",
            cursorOffset: 0,
            visibleRows: 3
        )
        let region = TerminalRegion(
            rows: 3,
            columns: 8
        )
        var initialFrame = TerminalFrame(
            rows: 3,
            columns: 8
        )

        editor.render(
            into: &initialFrame,
            in: region
        )

        _ = editor.handle(
            .char("j")
        )
        _ = editor.handle(
            .char("j")
        )

        var scrolledFrame = TerminalFrame(
            rows: 3,
            columns: 8
        )

        editor.render(
            into: &scrolledFrame,
            in: region
        )

        guard scrolledFrame.scrolls == [
            TerminalFrameScroll(
                top: 0,
                rows: 3,
                delta: 1
            ),
        ] else {
            throw Failure.unexpectedScrollHint
        }
    }
}
