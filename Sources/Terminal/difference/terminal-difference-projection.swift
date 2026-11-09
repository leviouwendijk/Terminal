import Difference

public extension TerminalDifferenceRenderer {
    /// Render semantic rows; legacy render(TextDifference) is unchanged.
    static func render(
        _ projection: DifferenceLayout.Projection,
        options: TerminalDifferenceRenderOptions = .init(),
        separator: String = "│",
        tabWidth: Int = 4
    ) -> String {
        if projection.mode == .unified {
            return render(unifiedLayout(projection), options: options)
        }
        let columns = max(24, options.columns ?? Terminal.size(for: .standardOutput).columns)
        let divider = " \(separator) "
        let dividerWidth = TerminalDisplay.width(of: divider)
        let remaining = max(2, columns - dividerWidth)
        let leftWidth = remaining / 2
        let rightWidth = remaining - leftWidth
        let lineWidth = max(2, String(projection.rows.compactMap { row -> Int? in
            max(row.old?.line ?? 0, row.new?.line ?? 0)
        }.max() ?? 0).count)
        let rendered = projection.rows.flatMap { row -> [String] in
            switch row.kind {
            case .headerOld:
                return [options.style.header.apply("--- " + row.text)]
            case .headerNew:
                return [options.style.header.apply("+++ " + row.text)]
            case .hunk:
                return [options.style.separator.apply(row.text)]
            case .collapsed:
                return [options.style.separator.apply(row.text)]
            case .endOfFile:
                return [options.style.separator.apply(row.text)]
            case .content:
                let left = splitCell(row.old, width: leftWidth, numberWidth: lineWidth,
                                     style: options.style, tabWidth: tabWidth)
                let right = splitCell(row.new, width: rightWidth, numberWidth: lineWidth,
                                      style: options.style, tabWidth: tabWidth)
                return (0..<max(left.count, right.count)).map { index in
                    let l = index < left.count ? left[index] : String(repeating: " ", count: leftWidth)
                    let r = index < right.count ? right[index] : String(repeating: " ", count: rightWidth)
                    return l + options.style.border.apply(divider) + r
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
        let firstPrefix = " \(number) \(marker) "
        let continuation = String(repeating: " ", count: TerminalDisplay.width(of: firstPrefix))
        let contentWidth = max(1, width - 1 - TerminalDisplay.width(of: firstPrefix))
        return wrapped(cell.text, width: contentWidth, tabWidth: tabWidth).enumerated().map { index, chunk in
            let prefix = index == 0 ? firstPrefix : continuation
            let body = TerminalDisplay.fitted(prefix + chunk, columns: width - 1)
            return barStyle.apply(bar) + bodyStyle.apply(body)
        }
    }

    /// Exact display-column wrapping; preserve indentation rather than word-reflowing.
    private static func wrapped(_ source: String, width: Int, tabWidth: Int) -> [String] {
        let width = max(1, width)
        let tabWidth = max(1, tabWidth)
        var lines: [String] = []
        var current = ""
        var columns = 0
        func add(_ character: String) {
            let size = TerminalDisplay.width(of: character)
            if columns > 0, columns + size > width {
                lines.append(current)
                current = ""
                columns = 0
            }
            if size > width {
                current += "?"
                columns += 1
            } else {
                current += character
                columns += size
            }
        }
        for character in source {
            if character == "\t" {
                let spaces = tabWidth - columns % tabWidth
                for _ in 0..<spaces { add(" ") }
            } else if let scalar = character.unicodeScalars.first,
                      character.unicodeScalars.count == 1,
                      scalar.value < 32 {
                add(UnicodeScalar(0x2400 + scalar.value).map(String.init) ?? "?")
            } else if character == "\u{007F}" {
                add("␡")
            } else {
                add(String(character))
            }
        }
        lines.append(current)
        return lines
    }
}
