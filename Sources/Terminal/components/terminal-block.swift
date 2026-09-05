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
            lines.append(
                contentsOf: TerminalTextWrap.lines(
                    body,
                    width: max(
                        1,
                        width
                    )
                )
            )
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

public enum TerminalInteractiveBlockState:
    String,
    Sendable,
    Hashable,
    CaseIterable
{
    case normal
    case focused
    case hovered
    case active
    case disabled
}

public struct TerminalInteractiveBlockStyle:
    Sendable,
    Hashable
{
    public var border: TerminalStyle
    public var focusedBorder: TerminalStyle
    public var hoveredBorder: TerminalStyle
    public var activeBorder: TerminalStyle
    public var disabledBorder: TerminalStyle
    public var title: TerminalStyle
    public var body: TerminalStyle
    public var hint: TerminalStyle
    public var disabledContent: TerminalStyle

    public init(
        border: TerminalStyle = .dim,
        focusedBorder: TerminalStyle = TerminalStyle(
            .bold,
            .brightCyan
        ),
        hoveredBorder: TerminalStyle = TerminalStyle(
            .brightCyan
        ),
        activeBorder: TerminalStyle = TerminalStyle(
            .bold,
            .brightCyan
        ),
        disabledBorder: TerminalStyle = .dim,
        title: TerminalStyle = .bold,
        body: TerminalStyle = .none,
        hint: TerminalStyle = .dim,
        disabledContent: TerminalStyle = .dim
    ) {
        self.border = border
        self.focusedBorder = focusedBorder
        self.hoveredBorder = hoveredBorder
        self.activeBorder = activeBorder
        self.disabledBorder = disabledBorder
        self.title = title
        self.body = body
        self.hint = hint
        self.disabledContent = disabledContent
    }

    public static let standard =
        TerminalInteractiveBlockStyle()

    public func borderStyle(
        for state: TerminalInteractiveBlockState
    ) -> TerminalStyle {
        switch state {
        case .normal:
            return border

        case .focused:
            return focusedBorder

        case .hovered:
            return hoveredBorder

        case .active:
            return activeBorder

        case .disabled:
            return disabledBorder
        }
    }

    public func titleStyle(
        for state: TerminalInteractiveBlockState
    ) -> TerminalStyle {
        switch state {
        case .focused:
            return focusedBorder

        case .hovered:
            return hoveredBorder

        case .active:
            return TerminalStyle(
                .inverse
            )

        case .disabled:
            return disabledContent

        case .normal:
            return title
        }
    }

    public func bodyStyle(
        for state: TerminalInteractiveBlockState
    ) -> TerminalStyle {
        state == .disabled
            ? disabledContent
            : body
    }

    public func hintStyle(
        for state: TerminalInteractiveBlockState
    ) -> TerminalStyle {
        state == .disabled
            ? disabledContent
            : hint
    }
}

public struct TerminalInteractiveBlock:
    Sendable,
    Hashable
{
    public var title: String
    public var body: String
    public var hint: String?
    public var state: TerminalInteractiveBlockState
    public var style: TerminalInteractiveBlockStyle
    public var horizontalPadding: Int

    public init(
        title: String,
        body: String,
        hint: String? = nil,
        state: TerminalInteractiveBlockState = .normal,
        style: TerminalInteractiveBlockStyle = .standard,
        horizontalPadding: Int = 2
    ) {
        self.title = title
        self.body = body
        self.hint = hint
        self.state = state
        self.style = style
        self.horizontalPadding = max(
            0,
            horizontalPadding
        )
    }

    public static func resolvedState(
        isEnabled: Bool = true,
        isFocused: Bool = false,
        isHovered: Bool = false,
        isActive: Bool = false
    ) -> TerminalInteractiveBlockState {
        guard isEnabled else {
            return .disabled
        }

        if isActive {
            return .active
        }

        if isFocused {
            return .focused
        }

        if isHovered {
            return .hovered
        }

        return .normal
    }

    public func render(
        width: Int
    ) -> [String] {
        let width = max(
            0,
            width
        )

        guard width > 0 else {
            return []
        }

        guard width >= 4 else {
            return [
                TerminalDisplay.fitted(
                    title,
                    columns: width
                ),
            ]
        }

        let innerColumns = width - 2
        let padding = min(
            horizontalPadding,
            max(
                0,
                (innerColumns - 1) / 2
            )
        )
        let contentColumns = max(
            1,
            innerColumns - (padding * 2)
        )
        let trailingPadding = max(
            0,
            innerColumns - padding - contentColumns
        )
        let leading = String(
            repeating: " ",
            count: padding
        )
        let trailing = String(
            repeating: " ",
            count: trailingPadding
        )
        let borderStyle = style.borderStyle(
            for: state
        )
        let titleStyle = style.titleStyle(
            for: state
        )
        let bodyStyle = style.bodyStyle(
            for: state
        )
        let hintStyle = style.hintStyle(
            for: state
        )

        let requestedTitle = title.isEmpty
            ? ""
            : " \(title) "
        let visibleTitle = TerminalDisplay.clipped(
            requestedTitle,
            columns: innerColumns
        )
        let remainingTopColumns = max(
            0,
            innerColumns
                - TerminalDisplay.width(
                    of: visibleTitle
                )
        )
        let top =
            borderStyle.apply("╭")
            + titleStyle.apply(visibleTitle)
            + borderStyle.apply(
                String(
                    repeating: "─",
                    count: remainingTopColumns
                )
                + "╮"
            )

        var content: [(
            text: String,
            isHint: Bool
        )] = TerminalTextWrap.lines(
            body,
            width: contentColumns
        ).map { line in
            (
                text: line,
                isHint: false
            )
        }

        if let hint,
           !hint.isEmpty
        {
            if !content.isEmpty {
                content.append(
                    (
                        text: "",
                        isHint: false
                    )
                )
            }

            content.append(
                contentsOf: TerminalTextWrap.lines(
                    hint,
                    width: contentColumns
                ).map { line in
                    (
                        text: line,
                        isHint: true
                    )
                }
            )
        }

        if content.isEmpty {
            content = [
                (
                    text: "",
                    isHint: false
                ),
            ]
        }

        var lines = [
            top,
        ]

        for row in content {
            let fitted = TerminalDisplay.fitted(
                row.text,
                columns: contentColumns
            )
            let styled = row.isHint
                ? hintStyle.apply(fitted)
                : bodyStyle.apply(fitted)

            lines.append(
                borderStyle.apply("│")
                    + leading
                    + styled
                    + trailing
                    + borderStyle.apply("│")
            )
        }

        lines.append(
            borderStyle.apply(
                "╰"
                    + String(
                        repeating: "─",
                        count: innerColumns
                    )
                    + "╯"
            )
        )

        return lines
    }

    public func hitRegion(
        in region: TerminalRegion
    ) -> TerminalRegion {
        TerminalRegion(
            top: region.top,
            leading: region.leading,
            rows: min(
                region.rows,
                render(
                    width: region.columns
                ).count
            ),
            columns: region.columns
        )
    }

    public func contains(
        row: Int,
        column: Int,
        in region: TerminalRegion
    ) -> Bool {
        let hitRegion = hitRegion(
            in: region
        )

        return row >= hitRegion.top
            && row < hitRegion.bottom
            && column >= hitRegion.leading
            && column < hitRegion.trailing
    }

    @discardableResult
    public func render(
        into frame: inout TerminalFrame,
        in region: TerminalRegion,
        zIndex: TerminalZIndex = .base
    ) -> TerminalRegion {
        let hitRegion = hitRegion(
            in: region
        )

        guard !hitRegion.isEmpty else {
            return hitRegion
        }

        frame.write(
            Array(
                render(
                    width: region.columns
                ).prefix(
                    hitRegion.rows
                )
            ),
            in: hitRegion,
            zIndex: zIndex
        )

        return hitRegion
    }
}
