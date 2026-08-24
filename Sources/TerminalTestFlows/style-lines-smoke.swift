import Terminal

enum TerminalStyleLinesSmoke {
    enum Failure:
        Error
    {
        case unexpectedStyledLines
        case unexpectedIndependentRow
        case unexpectedIdentityStyle
    }

    static func run() throws {
        let plain = [
            "alpha",
            "beta",
            "",
        ]

        let style = TerminalStyle(
            .dim,
            .brightCyan
        )

        let styled = style.apply(
            lines: plain
        )

        let expected = [
            "\u{001B}[2m\u{001B}[96malpha\u{001B}[0m",
            "\u{001B}[2m\u{001B}[96mbeta\u{001B}[0m",
            "\u{001B}[2m\u{001B}[96m\u{001B}[0m",
        ]

        guard styled == expected else {
            throw Failure.unexpectedStyledLines
        }

        guard styled[1] == style.apply(
            "beta"
        ) else {
            throw Failure.unexpectedIndependentRow
        }

        guard TerminalStyle.none.apply(
            lines: plain
        ) == plain else {
            throw Failure.unexpectedIdentityStyle
        }

        print(
            "style lines smoke passed"
        )
    }
}
