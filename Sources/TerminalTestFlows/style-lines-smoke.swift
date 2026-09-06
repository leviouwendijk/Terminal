import Terminal

enum TerminalStyleLinesSmoke {
    enum Failure: Error {
        case unexpectedStyledLines
        case unexpectedIndependentRow
        case unexpectedIdentityStyle
        case unexpectedHexColor
        case invalidHexColorAccepted
        case unexpectedRGBStyle
        case unexpectedMergedRGBStyle
        case unexpectedRGBStyledText
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

        guard let foreground = TerminalStyle.Color.hex(
            "#d0d0d0"
        ),
              let background = TerminalStyle.Color.hex(
                "#3a3d43"
              ),
              foreground.hex() == "#d0d0d0",
              background.hex() == "#3a3d43"
        else {
            throw Failure.unexpectedHexColor
        }

        guard TerminalStyle.Color.hex(
            "#3a3d4"
        ) == nil,
              TerminalStyle.Color.hex(
                "#3a3d4g"
              ) == nil
        else {
            throw Failure.invalidHexColorAccepted
        }

        let selectionStyle = TerminalStyle(
            foreground: .hex(
                "#d0d0d0"
            ),
            background: .hex(
                "#3a3d43"
            )
        )

        let selectionExpected =
            "\u{001B}[38;2;208;208;208m"
            + "\u{001B}[48;2;58;61;67m"
            + "selected"
            + "\u{001B}[0m"

        guard selectionStyle.apply(
            "selected"
        ) == selectionExpected else {
            throw Failure.unexpectedRGBStyle
        }

        let numericStyle = TerminalStyle(
            foreground: .rgb(
                red: 208,
                green: 208,
                blue: 208
            ),
            background: .rgb(
                red: 58,
                green: 61,
                blue: 67
            )
        )

        guard numericStyle.apply(
            "selected"
        ) == selectionExpected else {
            throw Failure.unexpectedRGBStyle
        }

        let merged = TerminalStyle(
            .bold
        ).merging(
            selectionStyle
        )
        let mergedExpected =
            "\u{001B}[1m"
            + "\u{001B}[38;2;208;208;208m"
            + "\u{001B}[48;2;58;61;67m"
            + "selected"
            + "\u{001B}[0m"

        guard merged.apply(
            "selected"
        ) == mergedExpected else {
            throw Failure.unexpectedMergedRGBStyle
        }

        let legacyForegroundOverlay = selectionStyle.merging(
            TerminalStyle(
                .red
            )
        )
        let legacyOverlayExpected =
            "\u{001B}[38;2;208;208;208m"
            + "\u{001B}[48;2;58;61;67m"
            + "\u{001B}[31m"
            + "selected"
            + "\u{001B}[0m"

        guard legacyForegroundOverlay.apply(
            "selected"
        ) == legacyOverlayExpected else {
            throw Failure.unexpectedMergedRGBStyle
        }

        let styledText = TerminalStyledText(
            text: "selected",
            style: TerminalStyle(
                .bold
            ),
            spans: [
                TerminalTextStyleSpan(
                    sourceRange: 0..<8,
                    style: selectionStyle
                ),
            ]
        )

        guard styledText.renderedRows(
            columns: 20
        ) == [
            mergedExpected,
        ] else {
            throw Failure.unexpectedRGBStyledText
        }

        print(
            "style lines smoke passed"
        )
    }
}
