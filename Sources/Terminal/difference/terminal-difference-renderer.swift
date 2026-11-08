import Difference

public struct TerminalDifferenceStyle: Sendable, Hashable {
    public var header: TerminalStyle
    public var lineNumbers: TerminalStyle
    public var border: TerminalStyle
    public var equal: TerminalStyle
    public var insert: TerminalStyle
    public var delete: TerminalStyle
    public var modified: TerminalStyle
    public var moved: TerminalStyle
    public var moved_modified: TerminalStyle
    public var separator: TerminalStyle
    public var insertBar: TerminalStyle
    public var deleteBar: TerminalStyle
    public var insertRow: TerminalStyle?
    public var deleteRow: TerminalStyle?

    public init(
        header: TerminalStyle = .init(.brightBlack),
        lineNumbers: TerminalStyle = .init(.brightBlack),
        border: TerminalStyle = .init(.brightBlack),
        equal: TerminalStyle = .dim,
        insert: TerminalStyle = .init(.green),
        delete: TerminalStyle = .init(.red),
        modified: TerminalStyle = .init(.yellow),
        moved: TerminalStyle = .init(.cyan),
        moved_modified: TerminalStyle = .init(.magenta),
        separator: TerminalStyle = .init(.brightBlack),
        insertBar: TerminalStyle = .init(.brightGreen),
        deleteBar: TerminalStyle = .init(.brightRed),
        insertRow: TerminalStyle? = nil,
        deleteRow: TerminalStyle? = nil
    ) {
        self.header = header
        self.lineNumbers = lineNumbers
        self.border = border
        self.equal = equal
        self.insert = insert
        self.delete = delete
        self.modified = modified
        self.moved = moved
        self.moved_modified = moved_modified
        self.separator = separator
        self.insertBar = insertBar
        self.deleteBar = deleteBar
        self.insertRow = insertRow
        self.deleteRow = deleteRow
    }

    public static let standard = TerminalDifferenceStyle()

    public static let filled = TerminalDifferenceStyle(
        insertRow: TerminalStyle(
            foreground: .rgb(red: 225, green: 245, blue: 233),
            background: .rgb(red: 29, green: 73, blue: 49)
        ),
        deleteRow: TerminalStyle(
            foreground: .rgb(red: 250, green: 225, blue: 228),
            background: .rgb(red: 90, green: 36, blue: 45)
        )
    )
}

public struct TerminalDifferenceRenderOptions: Sendable, Hashable {
    public var base: DifferenceRenderOptions
    public var style: TerminalDifferenceStyle
    public var columns: Int?
    public var show_movement_reasons: Bool

    public init(
        base: DifferenceRenderOptions = .unified,
        style: TerminalDifferenceStyle = .filled,
        columns: Int? = nil,
        show_movement_reasons: Bool = true
    ) {
        self.base = base
        self.style = style
        self.columns = columns
        self.show_movement_reasons = show_movement_reasons
    }
}

public enum TerminalDifferenceRenderer {
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
        options: TerminalDifferenceRenderOptions = .init()
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
        options: TerminalDifferenceRenderOptions = .init()
    ) -> String {
        render(
            DifferenceRenderPlan.make(
                layout,
                options: options.base
            ),
            style: options.style,
            columns: options.columns
        )
    }

    public static func print(
        _ difference: TextDifference,
        options: TerminalDifferenceRenderOptions = .init()
    ) {
        Swift.print(
            render(
                difference,
                options: printOptions(options)
            )
        )
    }

    public static func print(
        _ layout: DifferenceLayout,
        options: TerminalDifferenceRenderOptions = .init()
    ) {
        Swift.print(
            render(
                layout,
                options: printOptions(options)
            )
        )
    }

    private static func printOptions(
        _ options: TerminalDifferenceRenderOptions
    ) -> TerminalDifferenceRenderOptions {
        .init(
            base: options.base,
            style: options.style,
            columns: options.columns
                ?? Terminal.size(for: .standardOutput).columns,
            show_movement_reasons: options.show_movement_reasons
        )
    }

    private static func render(
        _ plan: DifferenceRenderPlan,
        style: TerminalDifferenceStyle,
        columns: Int?
    ) -> String {
        plan.lines
            .map {
                renderLine(
                    $0,
                    style: style,
                    columns: columns
                )
            }
            .joined(
                separator: "\n"
            )
    }

    private static func renderLine(
        _ line: DifferenceRenderPlan.Line,
        style: TerminalDifferenceStyle,
        columns: Int?
    ) -> String {
        let spacing = String(
            repeating: " ",
            count: line.componentSpacing
        )

        if let rowStyle = rowStyle(for: line.role, style: style),
           columns == nil,
           line.segments.contains(where: { $0.component == .bar }) {
            return line.segments.enumerated().map { index, segment in
                let effective = rowStyle.merging(
                    segmentStyle(segment, role: line.role, style: style)
                )
                let prefix = index == 0 ? "" : rowStyle.apply(spacing)
                return prefix + effective.apply(segment.text)
            }.joined()
        }

        if let rowStyle = rowStyle(for: line.role, style: style) {
            let text = line.segments
                .map(\.text)
                .joined(separator: spacing)

            let content = columns.map {
                TerminalDisplay.fitted(
                    text,
                    columns: $0
                )
            } ?? text

            return rowStyle.apply(content)
        }

        return line.segments
            .map {
                segmentStyle(
                    $0,
                    role: line.role,
                    style: style
                )
                .apply(
                    $0.text
                )
            }
            .joined(
                separator: spacing
            )
    }

    private static func rowStyle(
        for role: DifferenceLayout.Role,
        style: TerminalDifferenceStyle
    ) -> TerminalStyle? {
        switch role {
        case .insert:
            return style.insertRow
        case .delete:
            return style.deleteRow
        default:
            return nil
        }
    }

    private static func segmentStyle(
        _ segment: DifferenceRenderPlan.Segment,
        role: DifferenceLayout.Role,
        style: TerminalDifferenceStyle
    ) -> TerminalStyle {
        switch role {
        case 
            .headerOld,
            .headerNew:
            return style.header

        case .separator:
            return style.separator

        case .endOfFile:
            switch segment.component {
                case .lineNumbers:
                return style.lineNumbers

                case .border:
                return style.border

                case .bar,
                     .marker,
                     .text:
                return style.separator
            }

            case 
                .equal,
                .insert,
                .delete:
            switch segment.component {
                case .bar:
                    switch role {
                    case .insert: return style.insertBar
                    case .delete: return style.deleteBar
                    default: return style.border
                    }

                case .lineNumbers:
                    return style.lineNumbers

                case .border:
                    return style.border

                case 
                    .marker,
                    .text:
                return contentStyle(
                    for: role,
                    style: style
                )
            }
        }
    }

    private static func contentStyle(
        for role: DifferenceLayout.Role,
        style: TerminalDifferenceStyle
    ) -> TerminalStyle {
        switch role {
            case .equal:
            return style.equal

            case .insert:
            return style.insert

            case .delete:
            return style.delete

            case 
                .headerOld,
                .headerNew:
            return style.header

            case 
                .separator,
                .endOfFile:
            return style.separator
        }
    }
}
