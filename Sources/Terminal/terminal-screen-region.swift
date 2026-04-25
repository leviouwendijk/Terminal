public enum TerminalScreenRegion {
    public static func clearLinesFromCursor(
        count: Int,
        stream: TerminalStream = .standardError
    ) {
        guard count > 0 else {
            return
        }

        for index in 0..<count {
            Terminal.clearLine(
                on: stream
            )

            if index < count - 1 {
                Terminal.write(
                    "\n",
                    to: stream
                )
            }
        }

        if count > 1 {
            Terminal.write(
                ANSIColor.cursorUp.rawValue.replacingOccurrences(
                    of: "{n}",
                    with: "\(count - 1)"
                ),
                to: stream
            )
        }

        Terminal.write(
            ANSIColor.cursorLeft.rawValue.replacingOccurrences(
                of: "{n}",
                with: "999"
            ),
            to: stream
        )
    }

    public static func moveUp(
        _ count: Int,
        stream: TerminalStream = .standardError
    ) {
        guard count > 0 else {
            return
        }

        Terminal.write(
            ANSIColor.cursorUp.rawValue.replacingOccurrences(
                of: "{n}",
                with: "\(count)"
            ),
            to: stream
        )
    }

    public static func moveDown(
        _ count: Int,
        stream: TerminalStream = .standardError
    ) {
        guard count > 0 else {
            return
        }

        Terminal.write(
            ANSIColor.cursorDown.rawValue.replacingOccurrences(
                of: "{n}",
                with: "\(count)"
            ),
            to: stream
        )
    }

    public static func moveToLineStart(
        stream: TerminalStream = .standardError
    ) {
        Terminal.write(
            ANSIColor.cursorLeft.rawValue.replacingOccurrences(
                of: "{n}",
                with: "999"
            ),
            to: stream
        )
    }
}
