import Foundation
import Primitives
import Reporting
import Terminal
import TerminalGraph

extension TerminalReporting.Renderer {
    func factsRows(_ block: ReportBlock.Facts, width: Int) -> [String] {
        var output = block.title.map { rows($0, width: width) } ?? []
        let labelWidth = min(
            block.facts.map { TerminalDisplay.width(of: tidy($0.label)) }.max() ?? 0,
            max(6, width / 3)
        )
        let valueWidth = width - labelWidth - 2
        guard valueWidth >= 8 else {
            return output + block.facts.flatMap { rows("\($0.label): \($0.value)", width: width) }
        }
        let indent = String(repeating: " ", count: labelWidth + 2)
        for fact in block.facts {
            let label = TerminalDisplay.clipped(tidy(fact.label), columns: labelWidth)
            let padding = String(repeating: " ", count: labelWidth - TerminalDisplay.width(of: label))
            let values = rows(fact.value, width: valueWidth)
            for (index, value) in values.enumerated() {
                output.append((index == 0 ? label + padding + "  " : indent) + value)
            }
        }
        return output
    }

    func calloutRows(_ block: ReportBlock.Callout, width: Int) -> [String] {
        let symbol: String
        switch block.tone {
        case .info: symbol = "i"
        case .success: symbol = "✓"
        case .warning: symbol = "!"
        case .failure: symbol = "✗"
        }
        let heading = "\(symbol) " + (block.title ?? block.tone.rawValue.capitalized)
        let body = narrative.rows(block.content, columns: max(1, width - 2)).map { "│ " + $0 }
        return rows(heading, width: width) + body
    }

    func graphRows(_ block: ReportBlock.Graph, width: Int) -> [String] {
        var output = block.title.map { rows($0, width: width) } ?? []
        let labels = Dictionary(uniqueKeysWithValues: block.nodes.map { ($0.id, $0.label) })
        let graph = try? Primitives.Graph<String, String, String, String?>(
            nodes: block.nodes.map { .init(id: $0.id, value: $0.label) },
            edges: block.edges.map {
                .init(id: $0.id, source: $0.source, destination: $0.destination, value: $0.label)
            }
        )
        if let layout = try? graph?.layout() {
            let positions = Dictionary(uniqueKeysWithValues: layout.nodes.map { ($0.id, $0.position) })
            let references = block.references.map {
                GraphLayout<String, String>.ReferencePlacement(
                    id: $0.id,
                    target: $0.target,
                    position: positions[$0.target] ?? nil
                )
            }
            output += TerminalGraph.Renderer().project(
                layout,
                columns: width,
                label: { labels[$0] ?? $0 },
                references: references,
                referenceLabel: { $0 }
            ).lines
            for edge in block.edges {
                if let label = edge.label {
                    output += rows("\(labels[edge.source] ?? edge.source) → \(labels[edge.destination] ?? edge.destination): \(label)", width: width)
                }
            }
            return output
        }
        // Graphs with cycles stay inspectable as lists; the lane layout is acyclic only.
        let descriptions = block.nodes.map { "node \($0.id) · \($0.label)" }
            + block.edges.map { edge in
                "edge \(edge.id) · \(edge.source) -> \(edge.destination)" + (edge.label.map { " · \($0)" } ?? "")
            }
            + block.references.map { "reference \($0.id) -> \($0.target)" }
        return output + descriptions.flatMap { rows($0, width: width) }
    }

    func timelineRows(_ block: ReportBlock.Timeline, width: Int) -> [String] {
        let zone = block.zone
        var output = block.title.map { rows($0, width: width) } ?? []
        output += rows(TimelineAxis.range(block.start, block.end, zone: zone), width: width)

        let labelWidth = min(block.lanes.map { TerminalDisplay.width(of: tidy($0.label)) }.max() ?? 0, max(4, width / 4))
        let plotWidth = width - labelWidth - 3
        if plotWidth >= 12, !block.lanes.isEmpty {
            let axis = TimelineAxis(start: block.start, end: block.end, cells: plotWidth, zone: zone)
            let gutter = String(repeating: " ", count: labelWidth + 2)
            output.append(gutter + axis.labels)
            for lane in block.lanes {
                let label = TerminalDisplay.clipped(tidy(lane.label), columns: labelWidth)
                let padding = String(repeating: " ", count: labelWidth - TerminalDisplay.width(of: label))
                output.append(label + padding + " │" + axis.cells(lane.spans) + "│")
            }
            let used = Set(block.lanes.flatMap { $0.spans.map(\.mark) })
            let legend = ReportBlock.Timeline.Mark.allCases.filter(used.contains)
                .map { "\(TimelineAxis.glyph($0)) \($0.rawValue)" }
                .joined(separator: "  ")
            if !legend.isEmpty { output += rows(legend, width: width) }
        }

        let format = TimelineAxis.formatter("HH:mm", zone: zone)
        let multiDay = !Calendar.current.isDate(block.start, equalTo: block.end.addingTimeInterval(-1), toGranularity: .day)
        let dayFormat = TimelineAxis.formatter("EEE d MMM HH:mm", zone: zone)
        for lane in block.lanes {
            let listed = lane.spans.sorted { $0.start < $1.start }
            guard !listed.isEmpty else { continue }
            output.append("")
            output += rows(lane.label, width: width)
            for span in listed {
                let from = (multiDay ? dayFormat : format).string(from: span.start)
                let to = format.string(from: span.end)
                let text = "  \(TimelineAxis.glyph(span.mark)) \(from)–\(to) \(span.mark.rawValue)"
                    + (span.label.map { " · \($0)" } ?? "")
                output += rows(text, width: width)
            }
        }
        return output
    }

    func rows(_ text: String, width: Int) -> [String] {
        TerminalTextLayout(text: tidy(text), columns: width).rows.map(\.content)
    }

    func tidy(_ value: String) -> String {
        value.replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
    }
}

/// Maps a time window onto a fixed number of terminal cells.
struct TimelineAxis {
    let start: Date
    let end: Date
    let count: Int
    let zone: TimeZone

    init(start: Date, end: Date, cells: Int, zone: TimeZone) {
        self.start = start
        self.end = end
        self.count = cells
        self.zone = zone
    }

    var secondsPerCell: TimeInterval {
        end.timeIntervalSince(start) / Double(count)
    }

    /// Marks differ by height, not shade: terminals paint shade glyphs as
    /// flat tints, and full blocks in stacked lanes merge into one shape.
    static func glyph(_ mark: ReportBlock.Timeline.Mark) -> Character {
        switch mark {
        case .occupied: "▇"
        case .reserved: "▁"
        case .available: "▄"
        case .highlight: "▲"
        case .transit: "≈"
        }
    }

    /// Later marks win a shared cell: the subject of the report stays visible.
    static func precedence(_ mark: ReportBlock.Timeline.Mark) -> Int {
        switch mark {
        case .available: 0
        case .reserved: 1
        case .occupied: 2
        case .transit: 3
        case .highlight: 4
        }
    }

    func cells(_ spans: [ReportBlock.Timeline.Span]) -> String {
        var marks: [ReportBlock.Timeline.Mark?] = Array(repeating: nil, count: count)
        for span in spans.sorted(by: { Self.precedence($0.mark) < Self.precedence($1.mark) }) {
            guard span.end > start, span.start < end else { continue }
            let first = max(0, Int((span.start.timeIntervalSince(start) / secondsPerCell).rounded(.down)))
            // A span shorter than a cell still claims one, or it would vanish.
            let last = min(count, max(first + 1, Int((span.end.timeIntervalSince(start) / secondsPerCell).rounded(.up))))
            for index in first..<last { marks[index] = span.mark }
        }
        return String(marks.map { $0.map(Self.glyph) ?? " " })
    }

    /// Tick labels over the cells, spaced so they never collide.
    var labels: String {
        let duration = end.timeIntervalSince(start)
        let hourly = duration <= 36 * 3600
        let format = Self.formatter(hourly ? "HH" : "EEE d", zone: zone)
        let labelWidth = hourly ? 2 : 6
        let steps: [TimeInterval] = hourly
            ? [1, 2, 3, 4, 6, 12].map { $0 * 3600 }
            : [1, 2, 7, 14].map { $0 * 86_400 }
        let step = steps.first { $0 / secondsPerCell >= Double(labelWidth + 1) } ?? steps.last!

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        var tick = calendar.dateInterval(of: hourly ? .hour : .day, for: start)?.start ?? start
        if tick < start { tick = tick.addingTimeInterval(hourly ? 3600 : 86_400) }
        // Align ticks to the step so labels read 08 10 12, not 09 11 13.
        while hourly, calendar.component(.hour, from: tick) % Int(step / 3600) != 0, tick < end {
            tick = tick.addingTimeInterval(3600)
        }

        var line = Array(repeating: Character(" "), count: count + 1)
        // Daily labels sit over their day's cells, the partial first day
        // included, not at midnight left of the day's spans.
        if !hourly, step == 86_400 {
            var day = calendar.dateInterval(of: .day, for: start)?.start ?? start
            while day < end {
                let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
                let first = Int((max(day, start).timeIntervalSince(start) / secondsPerCell).rounded())
                let last = min(count, Int((min(next, end).timeIntervalSince(start) / secondsPerCell).rounded()))
                let text = Array(format.string(from: day))
                if last - first > text.count {
                    let position = first + (last - first - text.count) / 2
                    for (offset, character) in text.enumerated() { line[position + offset] = character }
                }
                day = next
            }
            return String(line).replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
        }
        while tick < end {
            let position = Int((tick.timeIntervalSince(start) / secondsPerCell).rounded())
            let text = Array(format.string(from: tick))
            if position + text.count <= line.count {
                for (offset, character) in text.enumerated() { line[position + offset] = character }
            }
            tick = tick.addingTimeInterval(step)
        }
        return String(line).replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
    }

    static func range(_ start: Date, _ end: Date, zone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let sameDay = calendar.isDate(start, inSameDayAs: end.addingTimeInterval(-1))
        let from = formatter("EEE d MMM HH:mm", zone: zone).string(from: start)
        let to = formatter(sameDay ? "HH:mm" : "EEE d MMM HH:mm", zone: zone).string(from: end)
        return "\(from) – \(to) · \(zone.identifier)"
    }

    static func formatter(_ format: String, zone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = zone
        formatter.dateFormat = format
        return formatter
    }
}
