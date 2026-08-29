public extension Terminal {
    static func enableBracketedPaste(
        on stream: TerminalStream = .standardError
    ) {
        Terminal.write(
            "\u{001B}[?2004h",
            to: stream
        )
    }

    static func disableBracketedPaste(
        on stream: TerminalStream = .standardError
    ) {
        Terminal.write(
            "\u{001B}[?2004l",
            to: stream
        )
    }
}
