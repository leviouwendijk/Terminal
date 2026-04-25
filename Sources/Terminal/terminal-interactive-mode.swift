public enum TerminalInteractiveSmoke {
    public static func runKeyProbe() throws {
        let session = try TerminalSession(
            options: .interactive
        )

        defer {
            session.restore()
        }

        let reader = TerminalKeyReader()

        Terminal.clearScreen()
        Terminal.moveCursor(
            line: 1,
            column: 1
        )
        Terminal.write(
            "Terminal key probe\n",
            to: .standardError
        )
        Terminal.write(
            "Press keys. Esc, Ctrl-C, or Ctrl-D exits.\n\n",
            to: .standardError
        )

        while true {
            let key = reader.readKey()

            Terminal.write(
                "key: \(key.description)\n",
                to: .standardError
            )

            if key.isExitLike {
                return
            }
        }
    }

    public static func runListProbe() throws {
        let session = try TerminalSession(
            options: .interactive
        )

        defer {
            session.restore()
        }

        let reader = TerminalKeyReader()
        var navigator = TerminalListNavigator(
            count: 5,
            selectedIndex: 0,
            wrapMode: .wrap
        )
        var selected = TerminalSelectionSet<Int>()

        while true {
            renderListProbe(
                navigator: navigator,
                selected: selected
            )

            let key = reader.readKey()

            switch key {
            case .up, .control("P"):
                navigator.moveUp()

            case .down, .control("N"):
                navigator.moveDown()

            case .space, .controlSpace:
                if let index = navigator.selection {
                    selected.toggle(
                        index
                    )
                }

            case .enter:
                return

            case .escape, .control("C"), .control("D"), .char("q"):
                selected.clear()
                return

            default:
                break
            }
        }
    }

    private static func renderListProbe(
        navigator: TerminalListNavigator,
        selected: TerminalSelectionSet<Int>
    ) {
        Terminal.clearScreen()
        Terminal.moveCursor(
            line: 1,
            column: 1
        )

        Terminal.write(
            "Terminal list probe\n",
            to: .standardError
        )
        Terminal.write(
            "Ctrl-P/up and Ctrl-N/down move. Space toggles. Enter accepts. q/Esc exits.\n\n",
            to: .standardError
        )

        for index in 0..<navigator.count {
            let isCurrent = navigator.selection == index
            let isSelected = selected.contains(
                index
            )

            let cursor = isCurrent ? ">" : " "
            let marker = isSelected ? "x" : " "
            let line = "\(cursor) [\(marker)] item \(index + 1)\n"

            if isCurrent {
                Terminal.write(
                    line.ansi(.inverse),
                    to: .standardError
                )
            } else {
                Terminal.write(
                    line,
                    to: .standardError
                )
            }
        }

        Terminal.flush(
            .standardError
        )
    }
}
