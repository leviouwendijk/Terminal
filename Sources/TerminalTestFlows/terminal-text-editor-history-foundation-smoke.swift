import Terminal

enum TerminalTextEditorHistoryFoundationSmoke {
    static func run() throws {
        try runInsertTransactionProbe()
        try runChangeTransactionProbe()
        try runReplaceTransactionProbe()
        try runBlockInsertTransactionProbe()
        try runRedoInvalidationProbe()
    }

    private static func runInsertTransactionProbe() throws {
        var editor = TerminalTextEditor(
            text: "abc",
            cursorOffset: 1,
            clipboard: .disabled
        )

        _ = editor.handle(
            .char("i")
        )
        _ = editor.handle(
            .char("X")
        )
        _ = editor.handle(
            .char("Y")
        )
        _ = editor.handle(
            .escape
        )

        guard editor.buffer.text == "aXYbc",
              editor.history.undoDepth == 1,
              editor.handle(
                .char("u")
              ) == .changed,
              editor.buffer.text == "abc",
              editor.buffer.cursorOffset == 1,
              editor.history.redoDepth == 1,
              editor.handle(
                .control("R")
              ) == .changed,
              editor.buffer.text == "aXYbc" else {
            throw TerminalTestFailure(
                probe: "text editor insert transaction undo redo",
                expectation: "one insert session is one undo step and Ctrl-R restores it",
                observed:
                    "text=\(editor.buffer.text) cursor=\(editor.buffer.cursorOffset) undo=\(editor.history.undoDepth) redo=\(editor.history.redoDepth)"
            )
        }
    }

    private static func runChangeTransactionProbe() throws {
        var editor = TerminalTextEditor(
            text: "alpha beta",
            cursorOffset: 0,
            clipboard: .disabled
        )

        _ = editor.handle(
            .char("c")
        )
        _ = editor.handle(
            .char("w")
        )
        _ = editor.handle(
            .char("X")
        )
        _ = editor.handle(
            .escape
        )

        guard editor.buffer.text == "X beta",
              editor.history.undoDepth == 1,
              editor.handle(
                .char("u")
              ) == .changed,
              editor.buffer.text == "alpha beta" else {
            throw TerminalTestFailure(
                probe: "text editor change transaction undo",
                expectation: "cw plus inserted payload is one undo step",
                observed:
                    "text=\(editor.buffer.text) undo=\(editor.history.undoDepth)"
            )
        }
    }

    private static func runReplaceTransactionProbe() throws {
        var editor = TerminalTextEditor(
            text: "abcd",
            cursorOffset: 0,
            clipboard: .disabled
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
        _ = editor.handle(
            .escape
        )

        guard editor.buffer.text == "XYcd",
              editor.history.undoDepth == 1,
              editor.handle(
                .char("u")
              ) == .changed,
              editor.buffer.text == "abcd",
              editor.handle(
                .control("R")
              ) == .changed,
              editor.buffer.text == "XYcd" else {
            throw TerminalTestFailure(
                probe: "text editor replace transaction undo redo",
                expectation: "R session is one undo step",
                observed:
                    "text=\(editor.buffer.text) undo=\(editor.history.undoDepth) redo=\(editor.history.redoDepth)"
            )
        }
    }

    private static func runBlockInsertTransactionProbe() throws {
        var editor = TerminalTextEditor(
            text: "ab\ncd",
            cursorOffset: 0,
            clipboard: .disabled
        )

        _ = editor.handle(
            .control("V")
        )
        _ = editor.handle(
            .char("j")
        )
        _ = editor.handle(
            .char("I")
        )
        _ = editor.handle(
            .char("X")
        )
        _ = editor.handle(
            .escape
        )

        guard editor.buffer.text == "Xab\nXcd",
              editor.history.undoDepth == 1,
              editor.handle(
                .char("u")
              ) == .changed,
              editor.buffer.text == "ab\ncd" else {
            throw TerminalTestFailure(
                probe: "text editor block insert transaction undo",
                expectation: "block insert replication is one undo step",
                observed:
                    "text=\(editor.buffer.text) undo=\(editor.history.undoDepth)"
            )
        }
    }

    private static func runRedoInvalidationProbe() throws {
        var editor = TerminalTextEditor(
            text: "abc",
            cursorOffset: 0,
            clipboard: .disabled
        )

        _ = editor.handle(
            .char("x")
        )
        _ = editor.handle(
            .char("u")
        )
        _ = editor.handle(
            .char("i")
        )
        _ = editor.handle(
            .char("Z")
        )
        _ = editor.handle(
            .escape
        )

        guard editor.buffer.text == "Zabc",
              !editor.history.canRedo,
              editor.handle(
                .control("R")
              ) == nil,
              editor.buffer.text == "Zabc" else {
            throw TerminalTestFailure(
                probe: "text editor redo invalidation",
                expectation: "new committed change clears redo history",
                observed:
                    "text=\(editor.buffer.text) redo=\(editor.history.redoDepth)"
            )
        }
    }
}
