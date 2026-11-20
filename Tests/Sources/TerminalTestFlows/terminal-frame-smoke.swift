import Terminal

enum TerminalFrameSmoke {
    static func run() throws {
        let stream = TerminalStream.standardError
        let session = try TerminalSession(
            options: TerminalSession.Options(
                useAlternateScreen: true,
                hideCursor: true,
                useRawMode: true,
                restoreOnInterrupt: true,
                outputStream: stream
            )
        )

        defer {
            session.restore()
        }

        let reader = TerminalKeyReader()
        var renderer = TerminalFrameRenderer(
            stream: stream
        )

        while true {
            renderer.render(
                frame(
                    size: Terminal.size(
                        for: stream
                    )
                )
            )

            guard let key = reader.readKey(
                timeoutMilliseconds: 100
            ) else {
                continue
            }

            switch key {
            case .char("q"),
                 .escape:
                return

            default:
                continue
            }
        }
    }

    private static func frame(
        size: TerminalSize
    ) -> TerminalFrame {
        var frame = TerminalFrame(
            rows: size.rows,
            columns: size.columns
        )

        let root = TerminalRegion(
            rows: size.rows,
            columns: size.columns
        ).inset(
            by: TerminalInsets(
                vertical: 1,
                horizontal: 2
            )
        )

        let vertical = TerminalLayout.vertical(
            in: root,
            [
                .fixed(2),
                .flex(1),
                .fixed(4),
            ],
            spacing: 1
        )

        let header = vertical[0]
        let body = vertical[1]
        let footer = vertical[2]

        frame.write(
            [
                TerminalStyle.bold.apply(
                    "terminal shell"
                ),
                TerminalStyle.dim.apply(
                    "persistent frame composition"
                ),
            ],
            in: header
        )

        let horizontal = TerminalLayout.horizontal(
            in: body,
            [
                .fixed(18),
                .flex(1),
            ],
            spacing: 2
        )

        frame.write(
            [
                TerminalStyle.dim.apply(
                    "sessions"
                ),
                TerminalStyle.bold.apply(
                    "> current"
                ),
                "  previous",
                "",
                TerminalStyle.dim.apply(
                    "views"
                ),
                "  runs",
                "  tools",
                "  tasks",
            ],
            in: horizontal[0]
        )

        frame.write(
            [
                TerminalStyle.bold.apply(
                    "you"
                ),
                "Build a stable interactive terminal shell.",
                "",
                TerminalStyle.bold.apply(
                    "assistant"
                ),
                "Frame composition now owns positioned output without owning runtime semantics.",
                "",
                TerminalStyle.dim.apply(
                    "activity"
                ),
                "rendering dirty rows only",
            ],
            in: horizontal[1]
        )

        frame.write(
            [
                TerminalStyle.dim.apply(
                    String(
                        repeating: "─",
                        count: footer.columns
                    )
                ),
                "> type a message...",
                "",
                TerminalStyle.dim.apply(
                    "q/esc exit"
                ),
            ],
            in: footer
        )

        return frame
    }
}
