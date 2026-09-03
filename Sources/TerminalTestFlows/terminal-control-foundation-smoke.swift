import Terminal

enum TerminalControlFoundationSmoke {
    enum Failure:
        Error
    {
        case unexpectedFocus
        case unexpectedList
        case unexpectedComposer
        case unexpectedAction
        case unexpectedLevelMeter
        case unexpectedSpinner
    }

    static func run() throws {
        try runFocusProbe()
        try runListProbe()
        try runComposerProbe()
        try runActionProbe()
        try runLevelMeterProbe()
        try runSpinnerProbe()
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

    private static func runActionProbe() throws {
        let action = TerminalActionControl(
            symbol: "●",
            label: "voice"
        )

        guard action.handle(
            .enter
        ) == .accepted,
              action.handle(
                .space
              ) == .accepted,
              stripANSI(
                action.render(
                    focused: true
                )
              ) == "[● voice]"
        else {
            throw Failure.unexpectedAction
        }

        let disabled = TerminalActionControl(
            symbol: "●",
            isEnabled: false
        )

        guard disabled.handle(
            .enter
        ) == nil else {
            throw Failure.unexpectedAction
        }
    }

    private static func runLevelMeterProbe() throws {
        var meter = TerminalLevelMeter(
            capacity: 2
        )

        meter.append(
            0
        )
        meter.append(
            1
        )

        guard meter.render() == "▁█" else {
            throw Failure.unexpectedLevelMeter
        }

        meter.append(
            0.5
        )

        guard meter.values.count == 2 else {
            throw Failure.unexpectedLevelMeter
        }

        meter.reset()

        guard meter.render().isEmpty else {
            throw Failure.unexpectedLevelMeter
        }
    }

    private static func runSpinnerProbe() throws {
        var state = TerminalSpinnerState()

        guard state.currentFrame == "⠋" else {
            throw Failure.unexpectedSpinner
        }

        _ = state.advance()

        guard state.currentFrame == "⠙" else {
            throw Failure.unexpectedSpinner
        }

        state.reset()

        guard state.currentFrame == "⠋" else {
            throw Failure.unexpectedSpinner
        }

        var control = TerminalSpinnerControl(
            label: "working"
        )

        let first = control.render()

        guard first.contains("⠋"),
              first.contains("working")
        else {
            throw Failure.unexpectedSpinner
        }

        _ = control.advance()

        guard control.render().contains("⠙") else {
            throw Failure.unexpectedSpinner
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