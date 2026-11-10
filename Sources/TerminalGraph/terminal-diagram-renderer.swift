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
            edgeLabel: (EdgeID) -> String,
            rowLabel: (Int) -> String = { _ in "" }
        ) -> Projection<NodeID, EdgeID, String> {
            let available = max(1, columns)
            let labels = Dictionary(uniqueKeysWithValues: diagram.nodes.map {
                ($0.id, clean(label($0.id)))
            })
            let width = min(14, max(5, (labels.values.map(\.count).max() ?? 0) + 2))
            let step = 6
            if diagram.nodes.isEmpty {
                return Projection(
                    lines: [TerminalDisplay.clipped("(empty graph)", columns: available)],
                    nodeRows: [:], edgeRows: [:], referenceRows: [:]
                )
            }
            guard diagram.lane_count <= 32, diagram.row_count <= 120 else {
                return compact(diagram, width: available, labels: labels,
                               edgeLabel: edgeLabel, rowLabel: rowLabel)
            }
            let rowLabels = (0..<diagram.row_count).map { clean(rowLabel($0)) }
            let axisWidth = rowLabels.map(\.count).max() ?? 0
            let axisPadding = axisWidth > 0 ? axisWidth + 2 : 0
            // Occupied lanes need label room; routing-only lanes do not.
            var halfWidths = Array(repeating: 0, count: diagram.lane_count)
            for node in diagram.nodes {
                let nodeWidth = min(width, (labels[node.id]?.count ?? 0) + 2)
                let lane = node.position.lane
                halfWidths[lane] = max(halfWidths[lane], (nodeWidth + 1) / 2)
            }
            func geometry(gap: Int) -> (centers: [Int], width: Int) {
                var centers = Array(repeating: 0, count: diagram.lane_count)
                centers[0] = halfWidths[0] + 1
                if centers.count > 1 {
                    for lane in 1..<centers.count {
                        let distance = max(2, halfWidths[lane - 1] + halfWidths[lane] + gap)
                        centers[lane] = centers[lane - 1] + distance
                    }
                }
                return (centers, centers[centers.count - 1] + halfWidths[halfWidths.count - 1] + 2)
            }
            var chosen: (centers: [Int], width: Int)?
            for gap in [4, 3, 2, 1] {
                let candidate = geometry(gap: gap)
                if candidate.width + axisPadding <= available {
                    chosen = candidate
                    break
                }
            }
            guard let chosen else {
                return compact(diagram, width: available, labels: labels,
                               edgeLabel: edgeLabel, rowLabel: rowLabel)
            }
            let graphicWidth = chosen.width
            let graphicHeight = (diagram.row_count - 1) * step + 1
            if graphicHeight > 700 || graphicWidth * graphicHeight > 150_000 {
                return compact(diagram, width: available, labels: labels,
                               edgeLabel: edgeLabel, rowLabel: rowLabel)
            }

            func x(_ p: GraphDiagram<NodeID, EdgeID>.Point) -> Int { chosen.centers[p.lane] }
            func y(_ p: GraphDiagram<NodeID, EdgeID>.Point) -> Int { p.row * step }

            var canvas = TerminalGraphCanvas<EdgeID>(columns: graphicWidth, rows: graphicHeight)
            var nodeRows: [NodeID: Int] = [:]
            var edgeRows: [EdgeID: Range<Int>] = [:]
            var routes: [EdgeID: [TerminalGraphStroke.Point]] = [:]
            let edgeLabels = Dictionary(uniqueKeysWithValues: diagram.edges.map {
                ($0.id, clean(edgeLabel($0.id)))
            })

            for node in diagram.nodes {
                let value = String((labels[node.id] ?? "").prefix(width - 2))
                let center = TerminalGraphStroke.Point(row: y(node.position), column: x(node.position))
                nodeRows[node.id] = center.row
                canvas.reserveNode("[" + value + "]", at: center)
                let incident = Set(diagram.edges.compactMap { edge in
                    edge.source == node.id || edge.destination == node.id ? edge.id : nil
                })
                canvas.registerJunction(at: center, incident: incident)
            }

            for edge in diagram.edges {
                let minimum = edge.points.map(\.row).min() ?? 0
                let maximum = edge.points.map(\.row).max() ?? 0
                edgeRows[edge.id] = (minimum * step)..<(maximum * step + 1)
                var route: [TerminalGraphStroke.Point] = []
                for (start, end) in zip(edge.points, edge.points.dropFirst()) {
                    let segment = canvas.trace(
                        edge.id,
                        from: .init(row: y(start), column: x(start)),
                        to: .init(row: y(end), column: x(end))
                    )
                    route.append(contentsOf: route.isEmpty ? segment : Array(segment.dropFirst()))
                }
                routes[edge.id] = route
            }

            // Reserve arrows using actual routed cells, rather than a character
            // stamped at a fixed offset from a node's center.
            let ordered = diagram.edges.enumerated().sorted { left, right in
                func priority(_ edge: GraphDiagram<NodeID, EdgeID>.Edge) -> Int {
                    guard let a = edge.points.dropLast().last, let b = edge.points.last else { return 3 }
                    return a.lane == b.lane ? 0 : (a.row == b.row ? 1 : 2)
                }
                let a = priority(left.element)
                let b = priority(right.element)
                return a == b ? left.offset < right.offset : a < b
            }
            for (_, edge) in ordered {
                guard let a = edge.points.dropLast().last, let b = edge.points.last,
                      let route = routes[edge.id], route.count >= 2 else { continue }
                let dr = b.row - a.row
                let dc = b.lane - a.lane
                let arrow: Character
                if dr != 0 && dc != 0 {
                    arrow = dr > 0 ? (dc > 0 ? "↘" : "↙") : (dc > 0 ? "↗" : "↖")
                } else if dr != 0 {
                    arrow = dr > 0 ? "▼" : "▲"
                } else {
                    arrow = dc > 0 ? "▶" : "◀"
                }
                _ = canvas.placeArrow(arrow, for: edge.id,
                                      along: Array(route.dropLast().reversed().prefix(16)))
            }

            var labelled: Set<EdgeID> = []
            for edge in diagram.edges {
                let value = edgeLabels[edge.id] ?? ""
                if value.isEmpty || canvas.placeLabel(value, near: routes[edge.id] ?? []) {
                    labelled.insert(edge.id)
                }
            }
            var lines = canvas.lines()
            if axisWidth > 0 {
                for row in lines.indices {
                    let value = row % step == 0 ? rowLabels[row / step] : ""
                    lines[row] = value + String(repeating: " ", count: axisWidth - value.count + 2) + lines[row]
                }
            }
            for edge in diagram.edges where !labelled.contains(edge.id) {
                let detail = "edge \(edge.id): \(edge.source) -> \(edge.destination) [\(edgeLabels[edge.id] ?? "")]"
                lines += TerminalTextLayout(text: detail, columns: available).rows.map(\.content)
            }
            return Projection(lines: lines, nodeRows: nodeRows,
                              edgeRows: edgeRows, referenceRows: [:])
        }

        private func compact<NodeID: Hashable, EdgeID: Hashable>(
            _ diagram: GraphDiagram<NodeID, EdgeID>,
            width: Int,
            labels: [NodeID: String],
            edgeLabel: (EdgeID) -> String,
            rowLabel: (Int) -> String
        ) -> Projection<NodeID, EdgeID, String> {
            var lines: [String] = []
            var nodeRows: [NodeID: Int] = [:]
            var edgeRows: [EdgeID: Range<Int>] = [:]
            for node in diagram.nodes {
                nodeRows[node.id] = lines.count
                let axis = clean(rowLabel(node.position.row))
                let annotation = axis.isEmpty ? "" : " (\(axis))"
                let text = "row \(node.position.row)\(annotation), lane \(node.position.lane): \(labels[node.id] ?? "")"
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


    }
}
