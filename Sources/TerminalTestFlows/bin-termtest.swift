import Foundation
import Terminal

enum TerminalTestCommand: String {
    case keys
    case list
    case menu
    case menuColor = "menu-color"
    case menuChain = "menu-chain"
    case listReview = "list-review"
    case navigation
    case styleLines = "style-lines"
    case choice
    case choiceState = "choice-state"
    case graph
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

            case .navigation:
                try TerminalNavigationSmoke.run()

            case .styleLines:
                try TerminalStyleLinesSmoke.run()

            case .choice:
                try TerminalChoiceSmoke.run()

            case .choiceState:
                try TerminalChoiceSmoke.runStateful()

            case .graph:
                try TerminalRelationshipGraphSmoke.run()

            case .help:
                printUsage()
            }
        } catch {
            Terminal.write(
                "termtest failed: \(error)\n",
                to: .standardError
            )
            exit(1)
        }
    }

    private static func printUsage() {
        Terminal.write(
            """
            termtest

            Usage:
                swift run termtest keys
                swift run termtest list
                swift run termtest menu
                swift run termtest menu-color
                swift run termtest menu-chain
                swift run termtest list-review
                swift run termtest navigation
                swift run termtest style-lines
                swift run termtest choice
                swift run termtest graph
                swift run termtest help

            Commands:
                keys          Show decoded keys until Esc, Ctrl-C, or Ctrl-D.
                list          Open a tiny interactive multi-selection list probe.
                menu          Open a tiny interactive single-pick menu probe.
                menu-color    Open a styled menu with colored final callback output.
                menu-chain    Pick an action, then optionally pick a follow-up.
                list-review   Multi-select review list with colored collapsed summary.
                navigation    Verify shared navigation defaults.
                style-lines   Verify independently styled/reset terminal rows.
                choice        Probe the high-level default-aware choice interface.
                choice-state  Probe semantic cursor retention on pick/cancel.
                graph         Render an input/output relationship graph probe.
                help          Show this help text.

            Notes:
                Interactive commands use raw terminal mode.
                If something goes wrong, Ctrl-C should restore the terminal.

            """
        )
    }
}
