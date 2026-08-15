import Terminal

enum TerminalChoiceSmoke {
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
