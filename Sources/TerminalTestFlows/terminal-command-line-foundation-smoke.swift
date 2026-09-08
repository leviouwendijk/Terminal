import Swim
import Terminal

enum TerminalCommandLineFoundationSmoke {
    static func run() throws {
        var commandLine = TerminalCommandLine()

        commandLine.begin()

        guard commandLine.isActive,
              commandLine.handle(
                .char("w")
              ) == .editing,
              commandLine.handle(
                .enter
              ) == .command(
                .write
              ) else {
            throw TerminalTestFailure(
                probe: "TerminalCommandLine write bridge",
                expectation: "active :w resolves through Swim",
                observed: "unexpected command-line state"
            )
        }

        commandLine.setStatus(
            "\"/tmp/agentic/inputbuffers/example.txt\" written"
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
    }
}
