import Terminal

enum TerminalNavigationSmoke {
    enum Failure:
        Error
    {
        case unexpectedNavigationBinding(
            String
        )
    }

    static func run() throws {
        try expect(
            .control("P"),
            .previous,
            on: .vertical
        )

        try expect(
            .control("N"),
            .next,
            on: .vertical
        )

        try expect(
            .control("P"),
            .previous,
            on: .horizontal
        )

        try expect(
            .control("N"),
            .next,
            on: .horizontal
        )

        try expect(
            .up,
            .previous,
            on: .vertical
        )

        try expect(
            .down,
            .next,
            on: .vertical
        )

        try expect(
            .char("k"),
            .previous,
            on: .vertical
        )

        try expect(
            .char("j"),
            .next,
            on: .vertical
        )

        try expect(
            .left,
            .previous,
            on: .horizontal
        )

        try expect(
            .right,
            .next,
            on: .horizontal
        )

        try expect(
            .char("h"),
            .previous,
            on: .horizontal
        )

        try expect(
            .char("l"),
            .next,
            on: .horizontal
        )

        guard TerminalKey.control("P")
                .isVerticalPrevious,
              TerminalKey.control("P")
                .isHorizontalPrevious,
              TerminalKey.control("N")
                .isVerticalNext,
              TerminalKey.control("N")
                .isHorizontalNext
        else {
            throw Failure
                .unexpectedNavigationBinding(
                    "Ctrl-P/Ctrl-N axis independence"
                )
        }

        print(
            "navigation smoke passed"
        )
    }

    private static func expect(
        _ key: TerminalKey,
        _ expected: TerminalNavigationAction,
        on axis: TerminalNavigationAxis
    ) throws {
        guard key.navigationAction(
            on: axis
        ) == expected else {
            throw Failure
                .unexpectedNavigationBinding(
                    "\(key) on \(axis)"
                )
        }
    }
}
