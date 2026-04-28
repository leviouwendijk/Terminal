import Foundation
import Terminal

enum TerminalTestCommand: String {
    case keys
    case list
    case menu
    case menuColor = "menu-color"
    case menuChain = "menu-chain"
    case listReview = "list-review"
    case help
}

@main
struct TerminalTest {
    static func main() {
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

            case .menu:
                try TerminalInteractiveSmoke.runMenuProbe()

            case .menuColor:
                try TerminalInteractiveSmoke.runColorMenuProbe()

            case .menuChain:
                try TerminalInteractiveSmoke.runChainedMenuProbe()

            case .listReview:
                try TerminalInteractiveSmoke.runReviewListProbe()

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
    }

    private static func printUsage() {
        Terminal.write(
            """
            terminaltest

            Usage:
                swift run terminaltest keys
                swift run terminaltest list
                swift run terminaltest menu
                swift run terminaltest menu-color
                swift run terminaltest menu-chain
                swift run terminaltest list-review
                swift run terminaltest help

            Commands:
                keys          Show decoded keys until Esc, Ctrl-C, or Ctrl-D.
                list          Open a tiny interactive multi-selection list probe.
                menu          Open a tiny interactive single-pick menu probe.
                menu-color    Open a styled menu with colored final callback output.
                menu-chain    Pick an action, then optionally pick a follow-up.
                list-review   Multi-select review list with colored collapsed summary.
                help          Show this help text.

            Notes:
                Interactive commands use raw terminal mode.
                If something goes wrong, Ctrl-C should restore the terminal.

            """
        )
    }
}
