import Terminal

enum TerminalKeyMapFoundationSmoke {
    private enum Action:
        Sendable
    {
        case requestQuit
        case submit
    }

    static func run() throws {
        var keyMap = TerminalKeyMap<Action>()

        keyMap.remap(
            .control("C"),
            to: .escape
        )
        keyMap.bindAction(
            .escape,
            to: .requestQuit
        )
        keyMap.bindAction(
            TerminalKeyStroke(
                key: .enter,
                modifiers: .control
            ),
            to: .submit
        )
        keyMap.consume(
            .control("G")
        )

        switch keyMap.resolveOrFallback(
            .control("C")
        ) {
        case .key(.escape):
            break

        default:
            throw TerminalTestFailure(
                probe: "TerminalKeyMap key remap",
                expectation: "control-C resolves once to escape",
                observed: "unexpected resolution"
            )
        }

        switch keyMap.resolveOrFallback(
            .escape
        ) {
        case .action(.requestQuit):
            break

        default:
            throw TerminalTestFailure(
                probe: "TerminalKeyMap action binding",
                expectation: "raw escape resolves to requestQuit",
                observed: "unexpected resolution"
            )
        }

        switch keyMap.resolveOrFallback(
            TerminalKeyStroke(
                key: .enter,
                modifiers: .control
            )
        ) {
        case .action(.submit):
            break

        default:
            throw TerminalTestFailure(
                probe: "TerminalKeyMap modified key action",
                expectation: "control-enter resolves to submit",
                observed: "unexpected resolution"
            )
        }

        switch keyMap.resolveOrFallback(
            TerminalKeyStroke(
                key: .enter
            )
        ) {
        case .key(.enter):
            break

        default:
            throw TerminalTestFailure(
                probe: "TerminalKeyMap unmodified enter fallback",
                expectation: "plain enter remains native",
                observed: "unexpected resolution"
            )
        }

        switch keyMap.resolveOrFallback(
            .char("x")
        ) {
        case .key(.char("x")):
            break

        default:
            throw TerminalTestFailure(
                probe: "TerminalKeyMap native fallback",
                expectation: "unmapped key falls through unchanged",
                observed: "unexpected resolution"
            )
        }

        switch keyMap.resolveOrFallback(
            .control("G")
        ) {
        case .consumed:
            break

        default:
            throw TerminalTestFailure(
                probe: "TerminalKeyMap consumed binding",
                expectation: "control-G consumed",
                observed: "unexpected resolution"
            )
        }

        guard keyMap.binding(
            for: .control("C")
        ) != nil else {
            throw TerminalTestFailure(
                probe: "TerminalKeyMap binding lookup",
                expectation: "control-C binding exists",
                observed: "nil"
            )
        }

        _ = keyMap.remove(
            .control("C")
        )

        switch keyMap.resolveOrFallback(
            .control("C")
        ) {
        case .key(.control("C")):
            break

        default:
            throw TerminalTestFailure(
                probe: "TerminalKeyMap removed binding fallback",
                expectation: "removed binding restores native key",
                observed: "unexpected resolution"
            )
        }
    }
}
