import Difference

public extension TerminalDifferenceRenderer {
    /// Project semantic rows to physical display cells before emitting ANSI.
    static func render(
        _ projection: DifferenceLayout.Projection,
        options: TerminalDifferenceRenderOptions = .init(),
        separator: String = "│",
        tabWidth: Int = 4
    ) -> String {
        var options = options
        if options.presentation == .plain {
            options.style = .plain
        }
        if projection.mode == .unified {
            if hasInline(projection) || options.wrap != .characters {
                return renderUnifiedInline(projection, options: options, tabWidth: tabWidth)
            }
            return render(unifiedLayout(projection), options: options)
        }
        let tab = max(1, tabWidth)
        let numberWidth = lineNumberWidth(projection)
        let minimumPane = numberWidth + 10
        let divider = " \(separator) "
        let dividerWidth = TerminalDisplay.width(of: divider)
        let naturalOld = max(minimumPane, projection.rows.compactMap(\.old).map {
            TerminalDifferenceCell.natural($0, tabWidth: tab) + numberWidth + 6
        }.max() ?? minimumPane)
        let naturalNew = max(minimumPane, projection.rows.compactMap(\.new).map {
            TerminalDifferenceCell.natural($0, tabWidth: tab) + numberWidth + 6
        }.max() ?? minimumPane)
        let available = max(1, Terminal.size(for: .standardOutput).columns)
        let naturalTotal = sum(naturalOld, naturalNew, dividerWidth)
        let total = resolvedWidth(options, natural: naturalTotal, available: available)
        let minimumTotal = minimumPane * 2 + dividerWidth
        if total < minimumTotal {
            if hasInline(projection) || options.wrap != .characters {
                return renderUnifiedInline(projection, options: options, tabWidth: tab)
            }
            return render(unifiedLayout(projection), options: options)
        }

        let usable = total - dividerWidth
        let extra = usable - minimumPane * 2
        let leftDemand = naturalOld - minimumPane
        let rightDemand = naturalNew - minimumPane
        let leftBase = min(leftDemand, extra / 2)
        let rightBase = min(rightDemand, extra - leftBase)
        let remainder = extra - leftBase - rightBase
        let leftWidth = minimumPane + leftBase + min(remainder, leftDemand - leftBase)
        let rightWidth = usable - leftWidth

        let physical = projection.rows.flatMap { row -> [String] in
            switch row.kind {
            case .headerOld:
                return [options.style.header.apply(TerminalDisplay.clipped("--- " + row.text, columns: total))]
            case .headerNew:
                return [options.style.header.apply(TerminalDisplay.clipped("+++ " + row.text, columns: total))]
            case .hunk, .collapsed, .endOfFile:
                return [options.style.separator.apply(TerminalDisplay.clipped(row.text, columns: total))]
            case .content:
                let left = TerminalDifferenceCell.make(row.old, width: leftWidth,
                    numberWidth: numberWidth, style: options.style, tabWidth: tab,
                    wrap: options.wrap)
                let right = TerminalDifferenceCell.make(row.new, width: rightWidth,
                    numberWidth: numberWidth, style: options.style, tabWidth: tab,
                    wrap: options.wrap)
                return (0..<max(left.lines.count, right.lines.count)).map { index in
                    let lhs = index < left.lines.count ? left.lines[index] : left.filler
                    let rhs = index < right.lines.count ? right.lines[index] : right.filler
                    return lhs.render() + options.style.border.apply(divider) + rhs.render()
                }
            }
        }
        return physical.joined(separator: "\n")
    }

    private static func hasInline(_ projection: DifferenceLayout.Projection) -> Bool {
        projection.rows.contains {
            !($0.old?.spans.isEmpty ?? true) || !($0.new?.spans.isEmpty ?? true)
        }
    }

    private static func lineNumberWidth(_ projection: DifferenceLayout.Projection) -> Int {
        max(2, String(projection.rows.map {
            max($0.old?.line ?? 0, $0.new?.line ?? 0)
        }.max() ?? 0).count)
    }

    private static func sum(_ left: Int, _ right: Int, _ divider: Int) -> Int {
        let (subtotal, overflow) = left.addingReportingOverflow(right)
        guard !overflow else { return Int.max }
        let (result, totalOverflow) = subtotal.addingReportingOverflow(divider)
        return totalOverflow ? Int.max : result
    }

    private static func resolvedWidth(
        _ options: TerminalDifferenceRenderOptions,
        natural: Int,
        available: Int
    ) -> Int {
        let policy = options.width ?? options.columns.map {
            TerminalDifferenceRenderOptions.Width.fixed($0)
        } ?? (options.presentation == .review ? .terminal : .content())
        switch policy {
        case .terminal:
            return available
        case .fixed(let value):
            return max(1, value)
        case .content(let padding, let limit):
            let cap = min(available, max(1, limit ?? available))
            let (desired, overflow) = natural.addingReportingOverflow(max(0, padding))
            return min(cap, overflow ? Int.max : desired)
        }
    }

    private static func unifiedLayout(_ projection: DifferenceLayout.Projection) -> DifferenceLayout {
        let lines: [DifferenceLayout.Line] = projection.rows.map { row in
            switch row.kind {
            case .headerOld:
                return .init(role: .headerOld, text: row.text)
            case .headerNew:
                return .init(role: .headerNew, text: row.text)
            case .hunk, .collapsed:
                return .init(role: .separator, text: row.text)
            case .endOfFile:
                return .init(role: .endOfFile, text: row.text)
            case .content:
                if let old = row.old, let new = row.new {
                    return .init(role: .equal, text: old.text,
                                 coordinate: .init(old: old.line, new: new.line))
                }
                if let old = row.old {
                    return .init(role: .delete, text: old.text, coordinate: .init(old: old.line))
                }
                if let new = row.new {
                    return .init(role: .insert, text: new.text, coordinate: .init(new: new.line))
                }
                return .init(role: .separator, text: "")
            }
        }
        return .init(lines: lines)
    }

    private static func renderUnifiedInline(
        _ projection: DifferenceLayout.Projection,
        options: TerminalDifferenceRenderOptions,
        tabWidth: Int
    ) -> String {
        let tab = max(1, tabWidth)
        let numberWidth = lineNumberWidth(projection)
        let prefixWidth = numberWidth * 2 + 5
        let natural = max(24, projection.rows.compactMap { row -> Int? in
            guard let cell = row.old ?? row.new else { return nil }
            return TerminalDifferenceCell.natural(cell, tabWidth: tab) + prefixWidth + 2
        }.max() ?? 24)
        let available = max(24, Terminal.size(for: .standardOutput).columns)
        let width = max(24, resolvedWidth(options, natural: natural, available: available))
        let lines = projection.rows.flatMap { row -> [String] in
            switch row.kind {
            case .headerOld:
                return [options.style.header.apply(TerminalDisplay.clipped("--- " + row.text, columns: width))]
            case .headerNew:
                return [options.style.header.apply(TerminalDisplay.clipped("+++ " + row.text, columns: width))]
            case .hunk, .collapsed, .endOfFile:
                return [options.style.separator.apply(TerminalDisplay.clipped(row.text, columns: width))]
            case .content:
                guard let cell = row.old ?? row.new else { return [] }
                let old = row.old.map { String($0.line) } ?? "-"
                let new = row.new.map { String($0.line) } ?? "-"
                let lhs = String(repeating: " ", count: max(0, numberWidth - old.count)) + old
                let rhs = String(repeating: " ", count: max(0, numberWidth - new.count)) + new
                let marker = cell.role == .delete ? "-" : (cell.role == .insert ? "+" : " ")
                let physical = TerminalDifferenceCell.make(
                    cell, width: width, prefix: " \(lhs):\(rhs) \(marker) ",
                    style: options.style, tabWidth: tab, wrap: options.wrap
                )
                return physical.lines.map { $0.render() }
            }
        }
        return lines.joined(separator: "\n")
    }
}
