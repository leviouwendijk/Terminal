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
        let labelWidth = fields
            .map(\.label.count)
            .max() ?? 0

        var lines: [String] = [
            theme.heading.apply(title)
        ]

        for field in fields {
            lines.append(
                contentsOf: renderField(
                    field,
                    labelWidth: labelWidth,
                    width: width
                )
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

    private func renderField(
        _ field: TerminalField,
        labelWidth: Int,
        width: Int
    ) -> [String] {
        let padding = String(
            repeating: " ",
            count: max(0, labelWidth - field.label.count)
        )
        let label = field.label + padding
        let visiblePrefix = "  \(label)  "
        let styledPrefix = "  \(theme.label.apply(label))  "
        let continuationPrefix = String(
            repeating: " ",
            count: visiblePrefix.count
        )
        let valueWidth = max(
            1,
            width - visiblePrefix.count
        )
        let wrapped = TerminalTextWrap.lines(
            field.value,
            width: valueWidth
        )

        guard let first = wrapped.first else {
            return [
                styledPrefix
            ]
        }

        var lines: [String] = [
            styledPrefix + theme.value.apply(first)
        ]

        for line in wrapped.dropFirst() {
            lines.append(
                continuationPrefix + theme.value.apply(line)
            )
        }

        return lines
    }
}
