import Terminal

enum TerminalChoiceSmoke {
    static func runStateful() throws {
        let result = try Terminal.chooseResult(
            "Stateful process mode",
            choices: [
                TerminalMenuItem(
                    id: "one",
                    title: "One"
                ),
                TerminalMenuItem(
                    id: "two",
                    title: "Two"
                ),
                TerminalMenuItem(
                    id: "three",
                    title: "Three"
                ),
            ],
            default: "two",
            instructions:
                "Move the cursor, then Enter picks or q/Esc cancels while retaining the current ID."
        )

        switch result {
        case .picked(
            let id
        ):
            print(
                "picked: \(id)"
            )

        case .cancelled(
            let current
        ):
            print(
                "cancelled current: \(current ?? "none")"
            )
        }
    }

    static func run() throws {
        let selected = try Terminal.choose(
            "Process mode",
            choices: [
                TerminalMenuItem(
                    id: "non-throwing",
                    title: "Non-throwing",
                    caption:
                        "Server handles and logs process failures."
                ),
                TerminalMenuItem(
                    id: "throwing",
                    title: "Throwing",
                    caption:
                        "Propagate failures from process.throwing.run()."
                ),
            ],
            default: "non-throwing"
        )

        print(
            "choice: "
                + (
                    selected
                    ?? "cancelled"
                )
        )
    }
}
