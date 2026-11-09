import Difference
import Tokens

/// Physical terminal cells are measured before applying ANSI styles.
/// Every rendered line owns exactly its declared display-column width.
enum TerminalDifferenceCell {
    struct Run {
        let text: String
        let style: TerminalStyle
        let columns: Int

        func render() -> String {
            style.apply(text)
        }
    }

    struct Line {
        let runs: [Run]
        let columns: Int

        func render() -> String {
            assert(runs.reduce(0) { $0 + $1.columns } == columns)
            return runs.map { $0.render() }.joined()
        }
    }

    struct Result {
        let lines: [Line]
        let filler: Line
    }

    private struct Unit {
        let text: String
        let columns: Int
        let changed: Bool
        let breakAfter: Bool
    }

    static func make(
        _ cell: DifferenceLayout.Cell?,
        width: Int,
        numberWidth: Int,
        style: TerminalDifferenceStyle,
        tabWidth: Int,
        wrap: TerminalDifferenceRenderOptions.Wrap = .characters
    ) -> Result {
        guard let cell else {
            let blank = Line(
                runs: [.init(text: String(repeating: " ", count: width), style: .none, columns: width)],
                columns: width
            )
            return .init(lines: [blank], filler: blank)
        }
        let number = String(cell.line)
        let digits = String(repeating: " ", count: max(0, numberWidth - number.count)) + number
        let marker = cell.role == .delete ? "-" : (cell.role == .insert ? "+" : " ")
        return make(
            cell,
            width: width,
            prefix: " \(digits) \(marker) ",
            style: style,
            tabWidth: tabWidth,
            wrap: wrap
        )
    }

    static func make(
        _ cell: DifferenceLayout.Cell,
        width: Int,
        prefix: String,
        style: TerminalDifferenceStyle,
        tabWidth: Int,
        wrap: TerminalDifferenceRenderOptions.Wrap = .characters
    ) -> Result {
        let isDelete = cell.role == .delete
        let isInsert = cell.role == .insert
        let changed = isDelete || isInsert
        let bar = changed ? "┃" : " "
        let barStyle = isDelete ? style.deleteBar : (isInsert ? style.insertBar : style.border)
        let rowStyle = isDelete ? (style.deleteRow ?? style.delete) :
            (isInsert ? (style.insertRow ?? style.insert) : style.equal)
        let inlineStyle = isDelete ? style.inlineDelete : style.inlineInsert

        let clippedPrefix = TerminalDisplay.clipped(prefix, columns: max(0, width - 3))
        let prefixWidth = TerminalDisplay.width(of: clippedPrefix)
        let contentWidth = max(1, width - 1 - prefixWidth - 1)
        let continuation = String(repeating: " ", count: prefixWidth)
        let breaks = preferredBoundaries(in: cell.text, policy: wrap)
        let pieces = Self.wrap(units(cell, tabWidth: tabWidth, breaks: breaks),
                          width: contentWidth, policy: wrap)

        let rows = pieces.enumerated().map { index, units -> Line in
            let start = index == 0 ? clippedPrefix : continuation
            var runs = [
                Run(text: bar, style: barStyle, columns: 1),
                Run(text: start, style: rowStyle, columns: prefixWidth)
            ]
            var current = ""
            var state: Bool?
            var occupied = 0
            func flush() {
                guard let state, !current.isEmpty else { return }
                let effective = state ? rowStyle.merging(inlineStyle) : rowStyle
                runs.append(.init(text: current, style: effective,
                                  columns: TerminalDisplay.width(of: current)))
                current = ""
            }
            for unit in units {
                if state != unit.changed {
                    flush()
                    state = unit.changed
                }
                current += unit.text
                occupied += unit.columns
            }
            flush()
            let padding = width - 1 - prefixWidth - occupied
            runs.append(.init(text: String(repeating: " ", count: padding),
                              style: rowStyle, columns: padding))
            return .init(runs: runs, columns: width)
        }

        let filler = Line(
            runs: [
                .init(text: bar, style: barStyle, columns: 1),
                .init(text: String(repeating: " ", count: width - 1),
                      style: rowStyle, columns: width - 1)
            ],
            columns: width
        )
        return .init(lines: rows, filler: filler)
    }

    static func natural(_ cell: DifferenceLayout.Cell, tabWidth: Int) -> Int {
        units(cell, tabWidth: tabWidth).reduce(0) { $0 + $1.columns }
    }

    private static func units(
        _ cell: DifferenceLayout.Cell, tabWidth: Int, breaks: Set<Int> = []
    ) -> [Unit] {
        let tabWidth = max(1, tabWidth)
        var output: [Unit] = []
        var column = 0
        var utf8 = 0
        for character in cell.text {
            let original = String(character)
            let end = utf8 + original.utf8.count
            let changed = cell.spans.contains { span in
                span.range.start.line == cell.line &&
                span.range.start.column <= utf8 + 1 &&
                end + 1 <= span.range.end.column
            }
            let shown: String
            if character == "\t" {
                shown = String(repeating: " ", count: tabWidth - column % tabWidth)
            } else if let scalar = original.unicodeScalars.first,
                      original.unicodeScalars.count == 1,
                      scalar.value < 32 {
                shown = UnicodeScalar(0x2400 + scalar.value).map(String.init) ?? "?"
            } else if character == "\u{007F}" {
                shown = "␡"
            } else {
                shown = original
            }
            // Expanded tabs must be splittable at physical-cell boundaries.
            let parts = Array(shown)
            for (index, part) in parts.enumerated() {
                let string = String(part)
                let columns = max(0, TerminalDisplay.width(of: string))
                output.append(.init(
                    text: string, columns: columns, changed: changed,
                    breakAfter: index == parts.count - 1 && breaks.contains(end)
                ))
                column += columns
            }
            utf8 = end
        }
        return output
    }

    private static func preferredBoundaries(
        in source: String,
        policy: TerminalDifferenceRenderOptions.Wrap
    ) -> Set<Int> {
        switch policy {
        case .characters:
            return []
        case .words:
            var offsets: Set<Int> = []
            var end = 0
            for character in source {
                end += String(character).utf8.count
                if character.isWhitespace { offsets.insert(end) }
            }
            return offsets
        case .tokens:
            guard let segments = try? TokenBoundaries.lexical(source) else { return [] }
            return Set(segments.map { $0.utf8.upperBound.offset })
        }
    }

    private static func wrap(
        _ units: [Unit], width: Int, policy: TerminalDifferenceRenderOptions.Wrap
    ) -> [[Unit]] {
        guard !units.isEmpty else { return [[]] }
        let width = max(1, width)
        var result: [[Unit]] = []
        var cursor = 0
        while cursor < units.count {
            var end = cursor
            var occupied = 0
            var preferred: Int?
            while end < units.count {
                let size = units[end].columns
                if size > width || (occupied > 0 && occupied + size > width) {
                    break
                }
                occupied += size
                end += 1
                if units[end - 1].breakAfter { preferred = end }
            }
            if end == cursor {
                // Preserve the pre-existing safe fallback for an oversized grapheme.
                result.append([.init(text: "?", columns: 1,
                                     changed: units[cursor].changed, breakAfter: false)])
                cursor += 1
                continue
            }
            let chosen: Int
            if policy != .characters, end < units.count, let preferred,
               preferred > cursor {
                chosen = preferred
            } else {
                chosen = end
            }
            result.append(Array(units[cursor..<chosen]))
            cursor = chosen
        }
        return result
    }
}
