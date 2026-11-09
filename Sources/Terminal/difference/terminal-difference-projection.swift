import Difference

public extension TerminalDifferenceRenderer {
    /// Explicit width policy for semantic split projections.
    /// `.content` measures both panes and caps them at the available terminal width.
    static func render(
        _ projection: DifferenceLayout.Projection,
        options: TerminalDifferenceRenderOptions = .init(),
        separator: String = "│",
        tabWidth: Int = 4
    ) -> String {
        if projection.mode == .unified {
            return render(unifiedLayout(projection), options: options)
        }

        let numberWidth = max(2, String(projection.rows.map {
            max($0.old?.line ?? 0, $0.new?.line ?? 0)
        }.max() ?? 0).count)
        let prefixWidth = numberWidth + 4
        let minimumPane = prefixWidth + 1 + 1 + 4
        let divider = " \(separator) "
        let dividerWidth = TerminalDisplay.width(of: divider)
        let tab = max(1, tabWidth)
        let naturalOld = max(minimumPane, projection.rows.compactMap(\.old).map {
            TerminalDisplay.width(of: expanded($0.text, tabWidth: tab)) + prefixWidth + 2
        }.max() ?? minimumPane)
        let naturalNew = max(minimumPane, projection.rows.compactMap(\.new).map {
            TerminalDisplay.width(of: expanded($0.text, tabWidth: tab)) + prefixWidth + 2
        }.max() ?? minimumPane)
        let terminal = max(1, Terminal.size(for: .standardOutput).columns)
        let widthPolicy = options.width ?? options.columns.map {
            TerminalDifferenceRenderOptions.Width.fixed($0)
        } ?? .content()
        let total: Int
        switch widthPolicy {
        case .terminal:
            total = terminal
        case .fixed(let columns):
            total = max(1, columns)
        case .content(let padding, let limit):
            let cap = min(terminal, max(1, limit ?? terminal))
            let (natural, overflow) = naturalOld.addingReportingOverflow(naturalNew)
            let desired = overflow ? cap : min(cap, natural + dividerWidth + max(0, padding))
            total = desired
        }

        let minimumTotal = minimumPane * 2 + dividerWidth
        if total < minimumTotal {
            // A split cannot fit without losing both panes' source gutters.
            // Unified mode remains accessible at any width.
            return render(unifiedLayout(projection), options: options)
        }
        let usable = total - dividerWidth
        let base = minimumPane * 2
        let extra = usable - base
        let wantsOld = naturalOld - minimumPane
        let wantsNew = naturalNew - minimumPane
        let wants = max(1, wantsOld + wantsNew)
        let leftExtra = min(extra, (extra * wantsOld) / wants)
        let oldWidth = minimumPane + leftExtra
        let newWidth = usable - oldWidth

        let rendered = projection.rows.flatMap { row -> [String] in
            switch row.kind {
            case .headerOld:
                return [options.style.header.apply(TerminalDisplay.clipped("--- " + row.text, columns: total))]
            case .headerNew:
                return [options.style.header.apply(TerminalDisplay.clipped("+++ " + row.text, columns: total))]
            case .hunk, .collapsed, .endOfFile:
                return [options.style.separator.apply(TerminalDisplay.clipped(row.text, columns: total))]
            case .content:
                let old = splitCell(row.old, width: oldWidth, numberWidth: numberWidth,
                                    style: options.style, tabWidth: tab)
                let new = splitCell(row.new, width: newWidth, numberWidth: numberWidth,
                                    style: options.style, tabWidth: tab)
                return (0..<max(old.count, new.count)).map { index in
                    let left = index < old.count ? old[index] : String(repeating: " ", count: oldWidth)
                    let right = index < new.count ? new[index] : String(repeating: " ", count: newWidth)
                    return left + options.style.border.apply(divider) + right
                }
            }
        }
        return rendered.joined(separator: "\n")
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

    private static func splitCell(
        _ cell: DifferenceLayout.Cell?,
        width: Int,
        numberWidth: Int,
        style: TerminalDifferenceStyle,
        tabWidth: Int
    ) -> [String] {
        guard let cell else { return [String(repeating: " ", count: width)] }
        let digits = String(cell.line)
        let number = String(repeating: " ", count: max(0, numberWidth - digits.count)) + digits
        let marker: String
        let bar: String
        let barStyle: TerminalStyle
        let bodyStyle: TerminalStyle
        switch cell.role {
        case .delete:
            marker = "-"
            bar = "┃"
            barStyle = style.deleteBar
            bodyStyle = style.deleteRow ?? style.delete
        case .insert:
            marker = "+"
            bar = "┃"
            barStyle = style.insertBar
            bodyStyle = style.insertRow ?? style.insert
        default:
            marker = " "
            bar = " "
            barStyle = style.border
            bodyStyle = style.equal
        }
        let prefix = " \(number) \(marker) "
        return styledCell(cell, width: width, prefix: prefix, bar: bar,
                          barStyle: barStyle, bodyStyle: bodyStyle, tabWidth: tabWidth)
    }

    private static func styledCell(
        _ cell: DifferenceLayout.Cell,
        width: Int,
        prefix: String,
        bar: String,
        barStyle: TerminalStyle,
        bodyStyle: TerminalStyle,
        tabWidth: Int
    ) -> [String] {
        let continuation = String(repeating: " ", count: TerminalDisplay.width(of: prefix))
        let contentWidth = max(1, width - 1 - TerminalDisplay.width(of: prefix) - 1)
        let source = expanded(cell.text, tabWidth: tabWidth)
        return wrapped(source, width: contentWidth).enumerated().map { index, chunk in
            let start = index == 0 ? prefix : continuation
            let body = TerminalDisplay.fitted(start + chunk + " ", columns: width - 1)
            return barStyle.apply(bar) + bodyStyle.apply(body)
        }
    }

    /// Replace terminal controls before measuring or wrapping a source line.
    private static func expanded(_ text: String, tabWidth: Int) -> String {
        var result = ""
        var column = 0
        for character in text {
            let value: String
            if character == "\t" {
                value = String(repeating: " ", count: tabWidth - column % tabWidth)
            } else if character == "\r" {
                value = "␍"
            } else if character == "\u{001B}" {
                value = "␛"
            } else if character == "\n" {
                value = "␊"
            } else {
                value = String(character)
            }
            result += value
            column += TerminalDisplay.width(of: value)
        }
        return result
    }

    /// Source-preserving display-column wrapping; never split a Character.
    private static func wrapped(_ text: String, width: Int) -> [String] {
        let width = max(1, width)
        var chunks: [String] = []
        var chunk = ""
        var columns = 0
        for character in text {
            let value = String(character)
            let size = TerminalDisplay.width(of: value)
            if columns > 0 && columns + size > width {
                chunks.append(chunk)
                chunk = ""
                columns = 0
            }
            guard size <= width else {
                chunk += "?"
                columns += 1
                continue
            }
            chunk += value
            columns += size
        }
        chunks.append(chunk)
        return chunks
    }
}
