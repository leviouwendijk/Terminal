import Foundation
import Math
import Reporting
import Search
import Terminal
import TerminalStructuredContent

/// Width-aware, read-only rendering of validated report documents.
public enum TerminalReporting {
    public struct Renderer: Sendable {
        public var narrative: TerminalStructuredContent.Renderer

        public init(narrative: TerminalStructuredContent.Renderer = .init()) {
            self.narrative = narrative
        }

        public func rows(_ document: ReportDocument, columns: Int, includeTitle: Bool = true) -> [String] {
            let width = max(1, columns)
            var datasets: [String: ReportDataset] = [:]
            for dataset in document.datasets { datasets[dataset.id] = dataset }
            var result = includeTitle ? textRows(document.title, width: width) : []

            for block in document.blocks {
                let section: [String]
                switch block {
                case .narrative(let content):
                    section = narrative.rows(content, columns: width)
                case .table(let spec):
                    if let dataset = datasets[spec.dataset] {
                        section = tableRows(spec, dataset: dataset, width: width)
                    } else {
                        section = textRows("Missing dataset: \(spec.dataset)", width: width)
                    }
                case .chart(let spec):
                    if let dataset = datasets[spec.dataset] {
                        section = chartRows(spec, dataset: dataset, width: width)
                    } else {
                        section = textRows("Missing dataset: \(spec.dataset)", width: width)
                    }
                }
                if !section.isEmpty {
                    if !result.isEmpty { result.append("") }
                    result += section
                }
            }
            return result
        }

        public func render(_ document: ReportDocument, columns: Int) -> String {
            rows(document, columns: columns).joined(separator: "\n")
        }

        private func tableRows(
            _ spec: ReportBlock.Table,
            dataset: ReportDataset,
            width: Int
        ) -> [String] {
            let indices = spec.columns.compactMap(dataset.columnIndex)
            var output = spec.title.map { textRows($0, width: width) } ?? []
            output += coverageRows(dataset.coverage, width: width)
            guard indices.count == spec.columns.count else {
                return output + textRows("[invalid table column reference]", width: width)
            }
            guard !indices.isEmpty else { return output + ["(no columns selected)"] }
            let names = indices.map { clean(dataset.columns[$0].name) }
            let values = dataset.rows.map { row in indices.map { display(row.values[$0]) } }
            let gap = 2
            let sizes = names.indices.map { column in
                max(TerminalDisplay.width(of: names[column]),
                    values.map { TerminalDisplay.width(of: $0[column]) }.max() ?? 0)
            }
            let required = sizes.reduce(0, +) + gap * (sizes.count - 1)
            guard required <= width else {
                return output + verticalTable(names: names, values: values, width: width)
            }
            let numerical = indices.map { index in
                [.integer, .decimal].contains(dataset.columns[index].kind)
            }
            func row(_ cells: [String]) -> String {
                cells.enumerated().map { index, cell in
                    let padding = String(
                        repeating: " ",
                        count: max(0, sizes[index] - TerminalDisplay.width(of: cell))
                    )
                    return numerical[index] ? padding + cell : cell + padding
                }.joined(separator: String(repeating: " ", count: gap))
            }
            output.append(row(names))
            output.append(row(sizes.map { String(repeating: "-", count: $0) }))
            output += values.map(row)
            if values.isEmpty { output.append("(no rows)") }
            return output
        }

        private func verticalTable(names: [String], values: [[String]], width: Int) -> [String] {
            guard !values.isEmpty else { return ["(no rows)"] }
            var output: [String] = []
            for (rowIndex, row) in values.enumerated() {
                if rowIndex > 0 { output.append("") }
                for (name, value) in zip(names, row) {
                    output += textRows("\(name): \(value)", width: width)
                }
            }
            return output
        }

        private func chartRows(
            _ spec: ReportBlock.Chart,
            dataset: ReportDataset,
            width: Int
        ) -> [String] {
            guard let x = dataset.columnIndex(spec.x),
                  let y = dataset.columnIndex(spec.y) else {
                return textRows("[invalid chart column reference]", width: width)
            }
            let labels = dataset.rows.map { display($0.values[x]) }
            let numbers = dataset.rows.map { decimal($0.values[y]) }
            var output = textRows(spec.title ?? "\(spec.y) by \(spec.x)", width: width)
            output += coverageRows(dataset.coverage, width: width)
            guard !labels.isEmpty else { return output + ["(no points)"] }
            switch spec.kind {
            case .bar:
                output += barRows(labels: labels, numbers: numbers, width: width)
            case .line:
                output += lineRows(labels: labels, numbers: numbers, width: width)
            }
            return output
        }

        /// Preserve exact decimal values; only the terminal's discrete cell positions are rounded.
        private func barRows(labels: [String], numbers: [Decimal?], width: Int) -> [String] {
            let present = numbers.compactMap { $0 }
            let lower = min(.zero, present.min() ?? .zero)
            let upper = max(.zero, present.max() ?? .zero)
            let values = numbers.map { display($0.map { .decimal($0) }) }
            let labelWidth = min(labels.map { TerminalDisplay.width(of: clean($0)) }.max() ?? 0,
                                 max(8, width / 4))
            let valueWidth = values.map { TerminalDisplay.width(of: $0) }.max() ?? 0
            let plotWidth = min(40, width - labelWidth - valueWidth - 4)
            guard plotWidth >= 4 else {
                return zip(labels, values).flatMap { label, value in
                    textRows("\(label): \(value)", width: width)
                }
            }
            let scale = lower < upper ? try? DecimalLinearScale(lower: lower, upper: upper) : nil
            let baseline = scale.flatMap { chartColumn(.zero, using: $0, width: plotWidth) } ?? 0
            var output: [String] = []
            for (index, label) in labels.enumerated() {
                let paddedLabel = pad(clean(label), width: labelWidth, alignRight: false)
                let paddedValue = pad(values[index], width: valueWidth, alignRight: true)
                var glyphs = Array(repeating: Character(" "), count: plotWidth)
                if let value = numbers[index], let scale,
                   let end = chartColumn(value, using: scale, width: plotWidth) {
                    let first = min(baseline, end)
                    let last = max(baseline, end)
                    if first < last {
                        for position in first..<last where position < plotWidth {
                            glyphs[position] = value < .zero ? "▇" : "█"
                        }
                    }
                    if baseline < plotWidth { glyphs[baseline] = "│" }
                } else if numbers[index] != nil, baseline < plotWidth {
                    glyphs[baseline] = "│" // all-zero series
                }
                output.append(paddedLabel + "  " + String(glyphs) + "  " + paddedValue)
            }
            return output
        }

        /// Convert an exact decimal position to bounded terminal cell geometry.
        private func chartColumn(_ value: Decimal, using scale: DecimalLinearScale, width: Int) -> Int? {
            guard let position = try? scale.position(of: value, scale: 16),
                  let rounded = try? DecimalArithmetic.calculate(
                    .multiply, lhs: position, rhs: Decimal(width), scale: 0
                  ) else { return nil }
            return min(width, max(0, NSDecimalNumber(decimal: rounded).intValue))
        }

        /// Ordered points are rendered as a sparkline; exact values remain listed below.
        private func lineRows(labels: [String], numbers: [Decimal?], width: Int) -> [String] {
            let present = numbers.compactMap { $0 }
            let low = present.min() ?? .zero
            let high = present.max() ?? .zero
            var output: [String] = []
            let plotWidth = max(0, width - 2)
            if !present.isEmpty, numbers.count <= plotWidth {
                let symbols: [Character] = Array("▁▂▃▄▅▆▇█")
                let scale = low < high ? try? DecimalLinearScale(lower: low, upper: high) : nil
                let points = numbers.map { value -> Character in
                    guard let value else { return " " }
                    guard let scale else { return "▄" }
                    let position = chartColumn(value, using: scale, width: 7) ?? 3
                    return symbols[min(7, max(0, position))]
                }
                output.append(String(points))
            } else {
                output.append("(sparkline unavailable at this width or magnitude)")
            }
            for (label, value) in zip(labels, numbers) {
                output += textRows("\(label): \(display(value.map { .decimal($0) }))", width: width)
            }
            return output
        }

        private func pad(_ value: String, width: Int, alignRight: Bool) -> String {
            let clipped = TerminalDisplay.clipped(value, columns: max(1, width))
            let padding = String(repeating: " ", count: max(0, width - TerminalDisplay.width(of: clipped)))
            return alignRight ? padding + clipped : clipped + padding
        }

        private func coverageRows(_ coverage: ReportDataset.Coverage, width: Int) -> [String] {
            switch coverage {
            case .complete: return []
            case .unknown: return textRows("[coverage unknown; totals not verified]", width: width)
            case .partial(let offset, let total):
                let end = total.map(String.init) ?? "?"
                return textRows("[partial data; offset \(offset), total \(end)]", width: width)
            }
        }

        private func decimal(_ value: StructuredValue?) -> Decimal? {
            guard let value else { return nil }
            switch value {
            case .decimal(let number): return number
            case .integer(let number): return Decimal(number)
            default: return nil
            }
        }

        private func display(_ value: StructuredValue?) -> String {
            guard let value else { return "—" }
            switch value {
            case .text(let text): return clean(text)
            case .integer(let number): return String(number)
            case .decimal(let number): return NSDecimalNumber(decimal: number).stringValue
            case .date(let date): return ISO8601DateFormatter().string(from: date)
            case .boolean(let value): return value ? "true" : "false"
            }
        }

        private func clean(_ value: String) -> String {
            value.replacingOccurrences(of: "\r", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\t", with: " ")
        }

        private func textRows(_ text: String, width: Int) -> [String] {
            TerminalTextLayout(text: clean(text), columns: width).rows.map(\.content)
        }
    }
}
