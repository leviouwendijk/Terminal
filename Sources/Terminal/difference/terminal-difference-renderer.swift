import Difference

public struct TerminalDifferenceStyle: Sendable, Hashable {
    public var header: TerminalStyle
    public var lineNumbers: TerminalStyle
    public var border: TerminalStyle
    public var equal: TerminalStyle
    public var insert: TerminalStyle
    public var delete: TerminalStyle
    public var separator: TerminalStyle

    public init(
        header: TerminalStyle = .init(.brightBlack),
        lineNumbers: TerminalStyle = .init(.brightBlack),
        border: TerminalStyle = .init(.brightBlack),
        equal: TerminalStyle = .dim,
        insert: TerminalStyle = .init(.green),
        delete: TerminalStyle = .init(.red),
        separator: TerminalStyle = .init(.brightBlack)
    ) {
        self.header = header
        self.lineNumbers = lineNumbers
        self.border = border
        self.equal = equal
        self.insert = insert
        self.delete = delete
        self.separator = separator
    }

    public static let standard = TerminalDifferenceStyle()
}

public struct TerminalDifferenceRenderOptions: Sendable, Hashable {
    public var base: DifferenceRenderOptions
    public var style: TerminalDifferenceStyle

    public init(
        base: DifferenceRenderOptions = .unified,
        style: TerminalDifferenceStyle = .standard
    ) {
        self.base = base
        self.style = style
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
            style: options.style
        )
    }

    public static func print(
        _ difference: TextDifference,
        options: TerminalDifferenceRenderOptions = .init()
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
        options: TerminalDifferenceRenderOptions = .init()
    ) {
        Swift.print(
            render(
                layout,
                options: options
            )
        )
    }

    private static func render(
        _ plan: DifferenceRenderPlan,
        style: TerminalDifferenceStyle
    ) -> String {
        plan.lines
            .map {
                renderLine(
                    $0,
                    style: style
                )
            }
            .joined(
                separator: "\n"
            )
    }

    private static func renderLine(
        _ line: DifferenceRenderPlan.Line,
        style: TerminalDifferenceStyle
    ) -> String {
        let spacing = String(
            repeating: " ",
            count: line.componentSpacing
        )

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

    private static func segmentStyle(
        _ segment: DifferenceRenderPlan.Segment,
        role: DifferenceLayout.Role,
        style: TerminalDifferenceStyle
    ) -> TerminalStyle {
        switch role {
        case .headerOld,
             .headerNew:
            return style.header

        case .separator:
            return style.separator

        case .equal,
             .insert,
             .delete:
            switch segment.component {
            case .lineNumbers:
                return style.lineNumbers

            case .border:
                return style.border

            case .marker,
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

        case .headerOld,
             .headerNew:
            return style.header

        case .separator:
            return style.separator
        }
    }
}
