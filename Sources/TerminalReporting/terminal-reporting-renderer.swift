import Foundation
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

        public func rows(_ document: ReportDocument, columns: Int) -> [String] {
            let width = max(1, columns)
            var datasets: [String: ReportDataset] = [:]
            for dataset in document.datasets { datasets[dataset.id] = dataset }
            var result = textRows(document.title, width: width)

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
            func row(_ cells: [String]) -> String {
                zip(cells, sizes).map { cell, size in
                    TerminalDisplay.fitted(cell, columns: size)
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

        private func barRows(labels: [String], numbers: [Decimal?], width: Int) -> [String] {
            let magnitudes = numbers.compactMap { amount -> Double? in
                guard let amount else { return nil }
                let value = abs(NSDecimalNumber(decimal: amount).doubleValue)
                return value.isFinite ? value : nil
            }
            let maximum = magnitudes.max() ?? 0
            var result: [String] = []
            for (label, amount) in zip(labels, numbers) {
                result += textRows("\(label): \(display(amount.map { .decimal($0) }))", width: width)
                guard let amount, maximum > 0, width >= 3 else { continue }
                let value = abs(NSDecimalNumber(decimal: amount).doubleValue)
                guard value.isFinite else { continue }
                let count = min(width - 2, max(0, Int((value / maximum * Double(width - 2)).rounded())))
                let glyph = amount < .zero ? "<" : "#"
                result.append("  " + String(repeating: glyph, count: count))
            }
            return result
        }

        /// Ordered points are rendered as a sparkline; each exact value remains listed below.
        private func lineRows(labels: [String], numbers: [Decimal?], width: Int) -> [String] {
            let finite: [Double] = numbers.compactMap {
                guard let value = $0 else { return nil }
                let number = NSDecimalNumber(decimal: value).doubleValue
                return number.isFinite ? number : nil
            }
            var output: [String] = []
            let plotWidth = max(0, width - 2)
            let low = finite.min() ?? 0
            let high = finite.max() ?? 0
            let range = high - low
            if numbers.count <= plotWidth && !finite.isEmpty
                && finite.count == numbers.compactMap({ $0 }).count
                && range.isFinite {
                let symbols: [Character] = Array("▁▂▃▄▅▆▇█")
                let points = numbers.map { value -> Character in
                    guard let value else { return " " }
                    let number = NSDecimalNumber(decimal: value).doubleValue
                    let scaled = range == 0 ? 3 : (number - low) / range * 7
                    let position = scaled.isFinite ? max(0, min(7, Int(scaled.rounded()))) : 3
                    return symbols[position]
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
