public struct TerminalField: Sendable, Hashable {
    public var label: String
    public var value: String

    public init(
        _ label: String,
        _ value: String
    ) {
        self.label = label
        self.value = value
    }
}

public struct TerminalBlock: Sendable, Hashable {
    public var title: String
    public var fields: [TerminalField]
    public var body: String?
    public var theme: TerminalTheme

    public init(
        title: String,
        fields: [TerminalField] = [],
        body: String? = nil,
        theme: TerminalTheme = .standard
    ) {
        self.title = title
        self.fields = fields
        self.body = body
        self.theme = theme
    }

    public func render() -> String {
        let labelWidth = fields
            .map(\.label.count)
            .max() ?? 0

        var lines: [String] = [
            theme.heading.apply(title)
        ]

        for field in fields {
            let padding = String(
                repeating: " ",
                count: max(0, labelWidth - field.label.count)
            )

            lines.append(
                "  \(theme.label.apply(field.label + padding))  \(theme.value.apply(field.value))"
            )
        }

        if let body,
           !body.isEmpty {
            lines.append("")
            lines.append(body)
        }

        lines.append("")

        return lines.joined(
            separator: "\n"
        )
    }
}
