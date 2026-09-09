import Terminal

enum TerminalCommandLineFoundationSmoke {
    static func run() throws {
        var commandLine = TerminalCommandLine()

        commandLine.begin()

        guard commandLine.isActive,
              commandLine.handle(
                .char("w")
              ) == .changed,
              commandLine.text == "w",
              commandLine.handle(
                .enter
              ) == .submitted(
                "w"
              ),
              !commandLine.isActive else {
            throw TerminalTestFailure(
                probe: "TerminalCommandLine generic submission",
                expectation: "active input w then submitted(w)",
                observed: "unexpected command-line state"
            )
        }

        commandLine.setStatus(
            "written"
        )

        var frame = TerminalFrame(
            rows: 1,
            columns: 64
        )

        commandLine.render(
            into: &frame,
            in: TerminalRegion(
                rows: 1,
                columns: 64
            )
        )

        guard !frame.spans.isEmpty else {
            throw TerminalTestFailure(
                probe: "TerminalCommandLine status rendering",
                expectation: "rendered status span",
                observed: "no spans"
            )
        }

        commandLine.begin(
            text: "quit"
        )

        guard commandLine.handle(
            .escape
        ) == .cancelled,
        !commandLine.isActive,
        commandLine.text.isEmpty else {
            throw TerminalTestFailure(
                probe: "TerminalCommandLine cancellation",
                expectation: "cancelled inactive empty",
                observed: "unexpected cancellation state"
            )
        }
    }
}
