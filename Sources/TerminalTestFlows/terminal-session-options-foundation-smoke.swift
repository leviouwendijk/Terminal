import Terminal

enum TerminalSessionOptionsFoundationSmoke {
    static func run() throws {
        let defaults = TerminalSession.Options()

        guard defaults.keyboardProtocol == .legacy,
              defaults.controlSignalBehavior == .signals else {
            throw TerminalTestFailure(
                probe: "TerminalSession default control signal behavior",
                expectation: "signals",
                observed: String(
                    describing: defaults.controlSignalBehavior
                )
            )
        }

        let input = TerminalSession.Options(
            useRawMode: true,
            keyboardProtocol: .kitty,
            controlSignalBehavior: .input,
            restoreOnInterrupt: true
        )

        guard input.keyboardProtocol == .kitty,
              input.controlSignalBehavior == .input,
              input.restoreOnInterrupt else {
            throw TerminalTestFailure(
                probe: "TerminalSession input control signal behavior",
                expectation: "input while retaining interrupt restoration",
                observed: "behavior=\(input.controlSignalBehavior) restore=\(input.restoreOnInterrupt)"
            )
        }

        guard TerminalSession.Options.interactive.keyboardProtocol == .legacy,
              TerminalSession.Options.interactive.controlSignalBehavior == .signals else {
            throw TerminalTestFailure(
                probe: "TerminalSession interactive compatibility default",
                expectation: "signals",
                observed: String(
                    describing: TerminalSession.Options.interactive.controlSignalBehavior
                )
            )
        }
    }
}
