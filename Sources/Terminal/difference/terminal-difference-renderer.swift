import Difference
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

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
    public var inlineInsert: TerminalStyle
    public var inlineDelete: TerminalStyle
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
        inlineInsert: TerminalStyle = .init(
            foreground: .rgb(red: 245, green: 255, blue: 248),
            background: .rgb(red: 18, green: 119, blue: 66),
            codes: [.bold]
        ),
        inlineDelete: TerminalStyle = .init(
            foreground: .rgb(red: 255, green: 245, blue: 246),
            background: .rgb(red: 164, green: 42, blue: 66),
            codes: [.bold]
        ),
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
        self.inlineInsert = inlineInsert
        self.inlineDelete = inlineDelete
        self.insertRow = insertRow
        self.deleteRow = deleteRow
    }

    public static let standard = TerminalDifferenceStyle()

    /// No ANSI sequences, including intraline and gutter styles.
    public static let plain = TerminalDifferenceStyle(
        header: .none,
        lineNumbers: .none,
        border: .none,
        equal: .none,
        insert: .none,
        delete: .none,
        modified: .none,
        moved: .none,
        moved_modified: .none,
        separator: .none,
        insertBar: .none,
        deleteBar: .none,
        inlineInsert: .none,
        inlineDelete: .none
    )

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
    public enum Width: Sendable, Hashable {
        case terminal
        case content(padding: Int = 2, limit: Int? = nil)
        case fixed(Int)
    }

    public enum Wrap: Sendable, Hashable {
        case characters
        case words
        case tokens
    }

    /// How a raw TextDifference should be presented. Prebuilt layouts retain
    /// their explicit render-plan semantics.
    public enum Presentation: Sendable, Hashable {
        case review
        case compact
        case plain
        case legacy
    }

    public static let reviewBase = DifferenceRenderOptions(
        showHeader: true,
        showUnchangedLines: false,
        contextLineCount: 3,
        collapseSeparator: " ... {count} unchanged lines",
        showHunkHeaders: true,
        lineComponents: [.bar, .lineNumbers, .border, .marker, .text],
        lineNumberFormat: .columns
    )

    public static let review = Self()
    public static let compact = Self(
        base: .unified,
        style: .standard,
        width: .content(),
        wrap: .tokens,
        presentation: .compact
    )
    public static let plain = Self(
        base: .unified,
        style: .plain,
        width: .content(),
        wrap: .tokens,
        presentation: .plain
    )
    public static let legacy = Self(
        base: .unified,
        style: .filled,
        wrap: .characters,
        presentation: .legacy
    )

    public var presentation: Presentation
    public var wrap: Wrap
    public var width: Width?
    public var base: DifferenceRenderOptions
    public var style: TerminalDifferenceStyle
    public var columns: Int?
    public var show_movement_reasons: Bool

    public init(
        base: DifferenceRenderOptions = Self.reviewBase,
        style: TerminalDifferenceStyle = .filled,
        columns: Int? = nil,
        width: Width? = nil,
        wrap: Wrap = .tokens,
        presentation: Presentation = .review,
        show_movement_reasons: Bool = true
    ) {
        self.base = base
        self.style = style
        self.columns = columns
        self.width = width
        self.wrap = wrap
        self.presentation = presentation
        self.show_movement_reasons = show_movement_reasons
    }

    /// Resolve layout at the actual space assigned by the parent view.
    /// Keep legacy `columns` in sync until all consumers migrate to `width`.
    public func constrained(to region: TerminalRegion) -> Self {
        var result = self
        let columns = max(1, region.columns)
        result.width = .fixed(columns)
        result.columns = columns
        return result
    }

    /// A single effective bound for legacy, tree, graph, and review paths.
    /// The content policy has no natural-width requirement for those paths,
    /// so it exposes its maximum available width here.
    var constrainedColumns: Int? {
        switch width {
        case .fixed(let value):
            return max(1, value)
        case .terminal:
            return max(1, Terminal.size(for: .standardOutput).columns)
        case .content(_, let limit):
            let terminal = max(1, Terminal.size(for: .standardOutput).columns)
            return min(terminal, max(1, limit ?? terminal))
        case nil:
            return columns.map { max(1, $0) }
        }
    }
}

public enum TerminalDifferenceRenderer {
    public static func render(
        _ difference: TextDifference
    ) -> String {
        render(
            difference,
            options: .review
        )
    }

    public static func render(
        _ difference: TextDifference,
        options: TerminalDifferenceRenderOptions = .review
    ) -> String {
        if options.presentation == .legacy {
            return render(
                DifferenceLayout.make(difference, options: options.base),
                options: options
            )
        }
        return render(difference.analyze(), options: options)
    }

    /// Already-computed intraline analysis can enter the same review pipeline
    /// without repeating the bounded comparison work.
    public static func render(
        _ analysis: TextDifference.Analysis,
        options: TerminalDifferenceRenderOptions = .review
    ) -> String {
        if options.presentation == .legacy {
            return render(analysis.difference, options: options)
        }
        let mode: DifferenceLayout.Mode
        switch options.presentation {
        case .review:
            mode = reviewWidth(options) >= 75 ? .split : .unified
        case .compact, .plain, .legacy:
            mode = .unified
        }
        return render(
            DifferenceLayout.project(analysis, mode: mode, options: options.base),
            options: options
        )
    }

    /// An already-built DifferenceLayout is an explicit legacy/custom layout;
    /// it has no original comparison from which to rederive intraline spans.
    public static func render(
        _ layout: DifferenceLayout,
        options: TerminalDifferenceRenderOptions = .legacy
    ) -> String {
        render(
            DifferenceRenderPlan.make(layout, options: options.base),
            style: options.presentation == .plain ? .plain : options.style,
            columns: options.constrainedColumns
        )
    }

    private static func reviewWidth(_ options: TerminalDifferenceRenderOptions) -> Int {
        options.constrainedColumns
            ?? max(1, Terminal.size(for: .standardOutput).columns)
    }

    public static func print(
        _ difference: TextDifference,
        options: TerminalDifferenceRenderOptions = .review
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
        options: TerminalDifferenceRenderOptions = .legacy
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
        var result = options
        #if canImport(Darwin) || canImport(Glibc)
        // Rendering to a String remains explicit; only print adapts to pipes.
        if isatty(STDOUT_FILENO) == 0, result.presentation != .legacy {
            result.presentation = .plain
            result.style = .plain
            result.width = .content()
        }
        #endif
        if result.presentation == .legacy, result.columns == nil {
            result.columns = Terminal.size(for: .standardOutput).columns
        }
        return result
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

        let rendered = line.segments
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
            .joined(separator: spacing)
        return columns.map {
            TerminalDisplay.clipped(rendered, columns: $0)
        } ?? rendered
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
