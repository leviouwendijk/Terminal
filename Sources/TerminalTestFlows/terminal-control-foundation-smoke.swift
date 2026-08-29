import Terminal

enum TerminalControlFoundationSmoke {
    enum Failure:
        Error
    {
        case unexpectedFocus
        case unexpectedList
        case unexpectedComposer
    }

    static func run() throws {
        try runFocusProbe()
        try runListProbe()
        try runComposerProbe()
    }

    private static func runFocusProbe() throws {
        var focus = TerminalFocusState(
            order: [
                "navigation",
                "composer",
            ],
            focused: "composer"
        )

        _ = focus.moveNext()

        guard focus.focused == "navigation" else {
            throw Failure.unexpectedFocus
        }

        _ = focus.movePrevious()

        guard focus.focused == "composer" else {
            throw Failure.unexpectedFocus
        }
    }

    private static func runListProbe() throws {
        var list = TerminalListControl(
            items: [
                1,
                2,
                3,
            ],
            currentID: 1,
            id: { $0 },
            isEnabled: {
                $0 != 2
            }
        )

        _ = list.handle(
            .down
        )

        guard list.currentID == 3 else {
            throw Failure.unexpectedList
        }

        guard list.handle(
            .enter
        ) == .accepted(3) else {
            throw Failure.unexpectedList
        }

        var frame = TerminalFrame(
            rows: 3,
            columns: 10
        )

        list.render(
            into: &frame,
            in: TerminalRegion(
                rows: 3,
                columns: 10
            ),
            row: {
                $0.isCurrent
                    ? "> \($0.item)"
                    : "  \($0.item)"
            }
        )

        guard frame.spans(
            inRow: 2
        ).first?.content == "> 3" else {
            throw Failure.unexpectedList
        }
    }

    private static func runComposerProbe() throws {
        var control = TerminalTextInputControl(
            input: TerminalTextInput(
                text: "a"
            ),
            prompt: "> ",
            placeholder: "type"
        )
        var frame = TerminalFrame(
            rows: 2,
            columns: 20
        )

        _ = control.handle(
            .char("b")
        )
        control.render(
            into: &frame,
            in: TerminalRegion(
                rows: 1,
                columns: 20
            ),
            isFocused: true
        )

        guard control.input.text == "ab",
              frame.cursor == TerminalFrameCursor(
                row: 0,
                column: 4
              ) else {
            throw Failure.unexpectedComposer
        }
    }
}
