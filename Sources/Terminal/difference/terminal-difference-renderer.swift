import Difference

public struct DifferenceTerminalStyle: Sendable, Hashable {
    public var header: TerminalStyle
    public var equal: TerminalStyle
    public var insert: TerminalStyle
    public var delete: TerminalStyle
    public var separator: TerminalStyle

    public init(
        header: TerminalStyle = .init(.brightBlack),
        equal: TerminalStyle = .dim,
        insert: TerminalStyle = .init(.green),
        delete: TerminalStyle = .init(.red),
        separator: TerminalStyle = .init(.brightBlack)
    ) {
        self.header = header
        self.equal = equal
        self.insert = insert
        self.delete = delete
        self.separator = separator
    }

    public static let `default` = Self()
}

public struct DifferenceTerminalRenderOptions: Sendable, Hashable {
    public var base: DifferenceRenderOptions
    public var style: DifferenceTerminalStyle

    public init(
        base: DifferenceRenderOptions = .unified,
        style: DifferenceTerminalStyle = .default
    ) {
        self.base = base
        self.style = style
    }
}

public extension DifferenceRenderer {
    enum Terminal {
        public static func render(
            _ difference: TextDifference
        ) -> String {
            render(
                difference,
                options: .init()
            )
        }

        public static func render(
            _ difference: TextDifference,
            options: DifferenceTerminalRenderOptions = .init()
        ) -> String {
            render(
                DifferenceLayout.make(
                    difference,
                    options: options.base
                ),
                options: options
            )
        }

        public static func render(
            _ layout: DifferenceLayout,
            options: DifferenceTerminalRenderOptions = .init()
        ) -> String {
            layout.lines
                .map {
                    renderLine(
                        $0,
                        options: options
                    )
                }
                .joined(
                    separator: "\n"
                )
        }

        public static func print(
            _ difference: TextDifference,
            options: DifferenceTerminalRenderOptions = .init()
        ) {
            Swift.print(
                render(
                    difference,
                    options: options
                )
            )
        }

        public static func print(
            _ layout: DifferenceLayout,
            options: DifferenceTerminalRenderOptions = .init()
        ) {
            Swift.print(
                render(
                    layout,
                    options: options
                )
            )
        }

        private static func renderLine(
            _ line: DifferenceLayout.Line,
            options: DifferenceTerminalRenderOptions
        ) -> String {
            switch line.role {
            case .headerOld:
                return options.style.header.apply(
                    "--- \(line.text)"
                )

            case .headerNew:
                return options.style.header.apply(
                    "+++ \(line.text)"
                )

            case .equal:
                return options.style.equal.apply(
                    options.base.equalPrefix + line.text
                )

            case .insert:
                return options.style.insert.apply(
                    options.base.insertPrefix + line.text
                )

            case .delete:
                return options.style.delete.apply(
                    options.base.deletePrefix + line.text
                )

            case .separator:
                return options.style.separator.apply(
                    line.text
                )
            }
        }
    }

    enum ANSI: DifferenceRendering {
        public static func render(
            _ difference: TextDifference
        ) -> String {
            Terminal.render(
                difference
            )
        }
    }
}
