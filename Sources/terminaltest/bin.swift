import Foundation
import Terminal

enum TerminalTestCommand: String {
    case keys
    case list
    case help
}

func printUsage() {
    Terminal.write(
        """
        terminaltest

        Usage:
            swift run terminaltest keys
            swift run terminaltest list
            swift run terminaltest help

        Commands:
            keys    Show decoded keys until Esc, Ctrl-C, or Ctrl-D.
            list    Open a tiny interactive list probe.
            help    Show this help text.

        Notes:
            The keys and list commands use raw terminal mode.
            If something goes wrong, Ctrl-C should restore the terminal.

        """
    )
}

let arguments = Array(
    CommandLine.arguments.dropFirst()
)

let command =
    arguments.first
    .flatMap(TerminalTestCommand.init(rawValue:))
    ?? .help

do {
    switch command {
    case .keys:
        try TerminalInteractiveSmoke.runKeyProbe()

    case .list:
        try TerminalInteractiveSmoke.runListProbe()

    case .help:
        printUsage()
    }
} catch {
    Terminal.write(
        "terminaltest failed: \(error)\n",
        to: .standardError
    )
    exit(1)
}
