public struct TerminalDetailDocument: Sendable, Hashable {
    public var title: String
    public var sections: [TerminalDetailSection]
    public var theme: TerminalTheme
    public var layout: TerminalBlockLayout

    public init(
        title: String,
        sections: [TerminalDetailSection] = [],
        theme: TerminalTheme = .standard,
        layout: TerminalBlockLayout = .standard
    ) {
        self.title = title
        self.sections = sections
        self.theme = theme
        self.layout = layout
    }

    public func render(
        stream: TerminalStream = .standardError
    ) -> String {
        render(
            width: Terminal.size(
                for: stream
            ).columns
        )
    }

    public func render(
        width: Int
    ) -> String {
        var blocks: [String] = [
            TerminalBlock(
                title: title,
                theme: theme,
                layout: layout
            ).render(
                width: width
            )
        ]

        for section in sections {
            blocks.append(
                section.render(
                    width: width,
                    theme: theme,
                    layout: layout
                )
            )
        }

        return blocks.joined()
    }
}

public struct TerminalDetailSection: Sendable, Hashable {
    public var title: String
    public var items: [TerminalDetailItem]

    public init(
        title: String,
        items: [TerminalDetailItem] = []
    ) {
        self.title = title
        self.items = items
    }

    public func render(
        width: Int,
        theme: TerminalTheme,
        layout: TerminalBlockLayout
    ) -> String {
        var fields: [TerminalField] = []
        var bodyLines: [String] = []

        for item in items {
            switch item {
            case .field(let label, let value):
                fields.append(
                    .init(
                        label,
                        value
                    )
                )

            case .list(let label, let values):
                fields.append(
                    .init(
                        label,
                        values
                            .map { "- \($0)" }
                            .joined(separator: "\n")
                    )
                )

            case .body(let body):
                bodyLines.append(
                    body
                )
            }
        }

        return TerminalBlock(
            title: title,
            fields: fields,
            body: bodyLines.isEmpty
                ? nil
                : bodyLines.joined(
                    separator: "\n\n"
                ),
            theme: theme,
            layout: layout
        ).render(
            width: width
        )
    }
}

public enum TerminalDetailItem: Sendable, Hashable {
    case field(
        label: String,
        value: String
    )

    case list(
        label: String,
        values: [String]
    )

    case body(
        String
    )
}
