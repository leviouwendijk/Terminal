import Strings

public enum TerminalBlockLabelWidth: Sendable, Hashable {
    case automatic
    case minimum(Int)
    case fixed(Int)

    func resolve(
        fields: [TerminalField]
    ) -> Int {
        let natural = fields
            .map(\.label.count)
            .max() ?? 0

        switch self {
        case .automatic:
            return natural

        case .minimum(let minimum):
            return max(
                natural,
                minimum
            )

        case .fixed(let width):
            return max(
                0,
                width
            )
        }
    }
}

public struct TerminalBlockLayout: Sendable, Hashable {
    public var fieldIndent: Int
    public var labelWidth: TerminalBlockLabelWidth
    public var labelValueSpacing: Int
    public var blankLinesAfter: Int

    public init(
        fieldIndent: Int = 2,
        labelWidth: TerminalBlockLabelWidth = .automatic,
        labelValueSpacing: Int = 2,
        blankLinesAfter: Int = 1
    ) {
        self.fieldIndent = max(
            0,
            fieldIndent
        )
        self.labelWidth = labelWidth
        self.labelValueSpacing = max(
            1,
            labelValueSpacing
        )
        self.blankLinesAfter = max(
            0,
            blankLinesAfter
        )
    }

    public static let standard = TerminalBlockLayout()

    public static let agentic = TerminalBlockLayout(
        fieldIndent: 2,
        labelWidth: .minimum(11),
        labelValueSpacing: 2,
        blankLinesAfter: 1
    )
}

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
    public var layout: TerminalBlockLayout

    public init(
        title: String,
        fields: [TerminalField] = [],
        body: String? = nil,
        theme: TerminalTheme = .standard,
        layout: TerminalBlockLayout = .standard
    ) {
        self.title = title
        self.fields = fields
        self.body = body
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
        let labelWidth = layout.labelWidth.resolve(
            fields: fields
        )

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

        appendBlockSpacing(
            to: &lines
        )

        return lines.joined(
            separator: "\n"
        )
    }

    private func renderField(
        _ field: TerminalField,
        labelWidth: Int,
        width: Int
    ) -> [String] {
        let indent = String(
            repeating: " ",
            count: layout.fieldIndent
        )
        let spacing = String(
            repeating: " ",
            count: layout.labelValueSpacing
        )
        let label = field.label.align(
            .left,
            labelWidth,
            " "
        )
        let visiblePrefix = indent + label + spacing
        let styledPrefix = indent + theme.label.apply(label) + spacing
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

    private func appendBlockSpacing(
        to lines: inout [String]
    ) {
        lines.append("")

        guard layout.blankLinesAfter > 0 else {
            return
        }

        for _ in 0..<layout.blankLinesAfter {
            lines.append("")
        }
    }
}
