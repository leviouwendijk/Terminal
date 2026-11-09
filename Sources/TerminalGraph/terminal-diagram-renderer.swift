import Foundation
import Primitives
import Terminal

public extension TerminalGraph {
    /// Terminal projection for the spatial GraphDiagram model.
    /// Rendering does not change the canonical node/edge identities or their order.
    struct DiagramRenderer: Sendable {
        public init() {}

        public func project<NodeID: Hashable, EdgeID: Hashable>(
            _ diagram: GraphDiagram<NodeID, EdgeID>,
            columns: Int,
            label: (NodeID) -> String,
            edgeLabel: (EdgeID) -> String
        ) -> Projection<NodeID, EdgeID, String> {
            let available = max(1, columns)
            let labels = Dictionary(uniqueKeysWithValues: diagram.nodes.map {
                ($0.id, clean(label($0.id)))
            })
            let width = min(14, max(5, (labels.values.map(\.count).max() ?? 0) + 2))
            let pitch = width + 4
            let step = 6
            if diagram.lane_count > 32 || diagram.row_count > 120 {
                return compact(diagram, width: available, labels: labels, edgeLabel: edgeLabel)
            }
            let graphicWidth = diagram.lane_count * pitch
            let graphicHeight = max(0, diagram.row_count - 1) * step + (diagram.nodes.isEmpty ? 0 : 1)

            if diagram.nodes.isEmpty { return Projection(
                lines: [TerminalDisplay.clipped("(empty graph)", columns: available)],
                nodeRows: [:], edgeRows: [:], referenceRows: [:]
            ) }
            if graphicWidth > available || graphicHeight > 700 ||
               diagram.lane_count > 32 || graphicWidth * graphicHeight > 150_000 {
                return compact(diagram, width: available, labels: labels, edgeLabel: edgeLabel)
            }

            let center = width / 2
            func x(_ p: GraphDiagram<NodeID, EdgeID>.Point) -> Int { p.lane * pitch + center + 1 }
            func y(_ p: GraphDiagram<NodeID, EdgeID>.Point) -> Int { p.row * step }
            var strokes = Array(repeating: Array(repeating: UInt8(0), count: graphicWidth), count: graphicHeight)
            var nodeRows: [NodeID: Int] = [:]
            var edgeRows: [EdgeID: Range<Int>] = [:]
            var edgeTexts: [(id: EdgeID, row: Int, column: Int, text: String)] = []
            var arrows: [(Int, Int, Character)] = []

            for edge in diagram.edges {
                let points = edge.points
                let low = points.map(\.row).min() ?? 0
                let high = points.map(\.row).max() ?? 0
                edgeRows[edge.id] = (low * step)..<(high * step + 1)
                var best: (length: Int, row: Int, column: Int)?
                for (start, end) in zip(points, points.dropFirst()) {
                    let r1 = y(start)
                    let r2 = y(end)
                    let c1 = x(start)
                    let c2 = x(end)
                    let dr = r1 == r2 ? 0 : (r2 > r1 ? 1 : -1)
                    let length = max(abs(r2 - r1), abs(c2 - c1))
                    TerminalGraphStroke.trace(
                        from: .init(row: r1, column: c1),
                        to: .init(row: r2, column: c2),
                        into: &strokes
                    )
                    if dr != 0 && length >= 4 && length > (best?.length ?? -1) {
                        best = (length, (r1 + r2) / 2, c1)
                    }
                }
                if let previous = points.dropLast().last, let destination = points.last {
                    let dr = y(destination) - y(previous)
                    let dc = x(destination) - x(previous)
                    if dr != 0 {
                        arrows.append((y(destination) - (dr > 0 ? 1 : -1), x(destination), dr > 0 ? "▼" : "▲"))
                    } else if dc != 0 {
                        let offset = width / 2 + 1
                        arrows.append((y(destination), x(destination) - (dc > 0 ? offset : -offset), dc > 0 ? "▶" : "◀"))
                    }
                }
                if let best {
                    edgeTexts.append((edge.id, best.row, best.column + 2, clean(edgeLabel(edge.id))))
                }
            }

            var canvas = strokes.map { $0.map(TerminalGraphStroke.glyph) }
            for (row, column, arrow) in arrows where row >= 0 && row < graphicHeight && column >= 0 && column < graphicWidth {
                canvas[row][column] = arrow
            }
            var labelled: Set<EdgeID> = []
            for text in edgeTexts {
                if draw(text.text, row: text.row, column: text.column,
                        canvas: &canvas, ifFree: true) {
                    labelled.insert(text.id)
                }
            }
            for node in diagram.nodes {
                let row = y(node.position)
                nodeRows[node.id] = row
                let value = String((labels[node.id] ?? "").prefix(width - 2))
                let box = "[" + value + "]"
                _ = draw(box, row: row, column: x(node.position) - box.count / 2,
                         canvas: &canvas, ifFree: false)
            }
            var lines = canvas.map { String($0).trimmingCharacters(in: .whitespaces) }
            // Edge details remain available even where cramped crossings prevent labels.
            for edge in diagram.edges where !labelled.contains(edge.id) {
                let line = "edge \(edge.id): \(edge.source) -> \(edge.destination) [\(clean(edgeLabel(edge.id)))]"
                lines += TerminalTextLayout(text: line, columns: available).rows.map(\.content)
            }
            return Projection(lines: lines, nodeRows: nodeRows,
                              edgeRows: edgeRows, referenceRows: [:])
        }

        private func compact<NodeID: Hashable, EdgeID: Hashable>(
            _ diagram: GraphDiagram<NodeID, EdgeID>,
            width: Int,
            labels: [NodeID: String],
            edgeLabel: (EdgeID) -> String
        ) -> Projection<NodeID, EdgeID, String> {
            var lines: [String] = []
            var nodeRows: [NodeID: Int] = [:]
            var edgeRows: [EdgeID: Range<Int>] = [:]
            for node in diagram.nodes {
                nodeRows[node.id] = lines.count
                let text = "row \(node.position.row), lane \(node.position.lane): \(labels[node.id] ?? "")"
                lines += TerminalTextLayout(text: text, columns: width).rows.map(\.content)
            }
            for edge in diagram.edges {
                let start = lines.count
                let text = "edge \(edge.id): \(edge.source) -> \(edge.destination) [\(clean(edgeLabel(edge.id)))]"
                lines += TerminalTextLayout(text: text, columns: width).rows.map(\.content)
                edgeRows[edge.id] = start..<lines.count
            }
            return Projection(lines: lines, nodeRows: nodeRows,
                              edgeRows: edgeRows, referenceRows: [:])
        }

        private func clean(_ source: String) -> String {
            String(source.replacingOccurrences(of: "\r", with: " ")
                .replacingOccurrences(of: "\n", with: " ").map { character in
                    TerminalDisplay.width(of: String(character)) == 1 &&
                    character != "\t" ? character : "?"
                })
        }

        private func draw(
            _ text: String, row: Int, column: Int,
            canvas: inout [[Character]], ifFree: Bool
        ) -> Bool {
            guard row >= 0 && row < canvas.count && column >= 0 &&
                  column + text.count <= canvas[row].count else { return false }
            if ifFree && canvas[row][column..<(column + text.count)].contains(where: { $0 != " " }) {
                return false
            }
            for (offset, character) in text.enumerated() {
                canvas[row][column + offset] = character
            }
            return true
        }


    }
}
