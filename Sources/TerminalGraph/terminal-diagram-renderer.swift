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
            var strokes = Array(repeating: Array(repeating: UInt8(0), count: graphicWidth), count: graphicHeight)
            // Retain edge ownership separately from the combined stroke mask.
            var strokeOwners: [Int: [EdgeID: UInt8]] = [:]
            var diagonalMarks: [(point: TerminalGraphStroke.Point, glyph: Character, id: EdgeID)] = []
            var nodeRows: [NodeID: Int] = [:]
            var edgeRows: [EdgeID: Range<Int>] = [:]
            var edgeTexts: [(id: EdgeID, firstRow: Int, lastRow: Int, column: Int, text: String)] = []
            let edgeLabels = Dictionary(uniqueKeysWithValues: diagram.edges.map {
                ($0.id, clean(edgeLabel($0.id)))
            })
            // Place arrowheads after the complete edge raster is available.
            // Prefer same-lane arrows near nodes, then alternating diagonals.
            var arrowRequests: [(
                priority: Int,
                order: Int,
                candidates: [TerminalGraphStroke.Point],
                glyph: Character
            )] = []

            for edge in diagram.edges {
                let points = edge.points
                let low = points.map(\.row).min() ?? 0
                let high = points.map(\.row).max() ?? 0
                edgeRows[edge.id] = (low * step)..<(high * step + 1)
                var best: (length: Int, firstRow: Int, lastRow: Int, column: Int)?
                var diagonalLabel: (firstRow: Int, lastRow: Int, column: Int)?
                for (start, end) in zip(points, points.dropFirst()) {
                    let r1 = y(start)
                    let r2 = y(end)
                    let c1 = x(start)
                    let c2 = x(end)
                    let dr = r2 - r1
                    let dc = c2 - c1
                    let length = max(abs(dr), abs(dc))

                    if dr != 0 && dc != 0 {
                        let sampled = TerminalGraphStroke.diagonalPoints(
                            from: .init(row: r1, column: c1),
                            to: .init(row: r2, column: c2)
                        )
                        let marks = TerminalGraphStroke.diagonalMarks(
                            from: .init(row: r1, column: c1),
                            to: .init(row: r2, column: c2)
                        )
                        for mark in marks {
                            diagonalMarks.append((mark.point, mark.glyph, edge.id))
                        }
                        if diagonalLabel == nil && !sampled.isEmpty {
                            let midpoint = sampled[sampled.count / 2]
                            diagonalLabel = (min(r1, r2), max(r1, r2), midpoint.column)
                        }
                    } else {
                        TerminalGraphStroke.trace(
                            from: .init(row: r1, column: c1),
                            to: .init(row: r2, column: c2),
                            into: &strokes,
                            record: { point, mask in
                                let cell = point.row * graphicWidth + point.column
                                strokeOwners[cell, default: [:]][edge.id, default: 0] |= mask
                            }
                        )
                        if dr != 0 && length >= 4 && length > (best?.length ?? -1) {
                            best = (length, min(r1, r2), max(r1, r2), c1)
                        }
                    }
                }
                if let previous = points.dropLast().last, let destination = points.last {
                    let source = TerminalGraphStroke.Point(row: y(previous), column: x(previous))
                    let target = TerminalGraphStroke.Point(row: y(destination), column: x(destination))
                    let dr = target.row - source.row
                    let dc = target.column - source.column
                    let candidates: [TerminalGraphStroke.Point]
                    let glyph: Character
                    let priority: Int
                    if dr != 0 && dc != 0 {
                        let sampled = TerminalGraphStroke.diagonalPoints(from: source, to: target)
                        candidates = Array(sampled.dropLast().reversed().prefix(8))
                        glyph = dr > 0 ? (dc > 0 ? "↘" : "↙") : (dc > 0 ? "↗" : "↖")
                        priority = 2
                    } else if dr != 0 || dc != 0 {
                        let steps = max(abs(dr), abs(dc))
                        let rowStep = dr == 0 ? 0 : (dr > 0 ? 1 : -1)
                        let columnStep = dc == 0 ? 0 : (dc > 0 ? 1 : -1)
                        candidates = (1...min(8, steps)).map { offset in
                            .init(row: target.row - rowStep * offset,
                                  column: target.column - columnStep * offset)
                        }
                        glyph = dr != 0 ? (dr > 0 ? "▼" : "▲") : (dc > 0 ? "▶" : "◀")
                        priority = dc == 0 ? 0 : 1
                    } else {
                        candidates = []
                        glyph = " "
                        priority = 3
                    }
                    if !candidates.isEmpty {
                        arrowRequests.append((priority, arrowRequests.count, candidates, glyph))
                    }
                }
                if let best {
                    edgeTexts.append((edge.id, best.firstRow, best.lastRow, best.column, edgeLabels[edge.id] ?? ""))
                } else if let diagonalLabel {
                    edgeTexts.append((edge.id, diagonalLabel.firstRow, diagonalLabel.lastRow,
                                      diagonalLabel.column, edgeLabels[edge.id] ?? ""))
                }
            }

            var canvas = strokes.map { $0.map(TerminalGraphStroke.glyph) }
            for (cell, owners) in strokeOwners {
                let horizontal = owners.filter { ($0.value & 10) == 10 }.map(\.key)
                let vertical = owners.filter { ($0.value & 5) == 5 }.map(\.key)
                if horizontal.contains(where: { h in vertical.contains(where: { $0 != h }) }) {
                    // Independent through-routes cross here; they do not join.
                    canvas[cell / graphicWidth][cell % graphicWidth] = "╳"
                }
            }
            var diagonalOwners: [Int: Set<EdgeID>] = [:]
            for mark in diagonalMarks {
                let row = mark.point.row
                let column = mark.point.column
                guard row >= 0 && row < graphicHeight &&
                      column >= 0 && column < graphicWidth else { continue }
                let cell = row * graphicWidth + column
                let otherOrthogonal = strokeOwners[cell]?.keys.contains(where: { $0 != mark.id }) ?? false
                let otherDiagonal = diagonalOwners[cell]?.contains(where: { $0 != mark.id }) ?? false
                if otherOrthogonal || otherDiagonal || canvas[row][column] == "╳" {
                    canvas[row][column] = "╳"
                } else {
                    canvas[row][column] = mark.glyph
                }
                diagonalOwners[cell, default: []].insert(mark.id)
            }
            // Reserve the actual node-box footprints before placing arrows.
            // Arrowheads may move back along their own edge, but never into
            // another node or immediately beside another arrowhead.
            var nodeCells: Set<Int> = []
            for node in diagram.nodes {
                let value = String((labels[node.id] ?? "").prefix(width - 2))
                let boxWidth = value.count + 2
                let row = y(node.position)
                let start = x(node.position) - boxWidth / 2
                for column in start..<(start + boxWidth) {
                    nodeCells.insert(row * graphicWidth + column)
                }
            }
            var placedArrows: [TerminalGraphStroke.Point] = []
            let orderedArrows = arrowRequests.sorted { a, b in
                a.priority == b.priority ? a.order < b.order : a.priority < b.priority
            }
            for request in orderedArrows {
                for point in request.candidates {
                    guard point.row >= 0 && point.row < graphicHeight &&
                          point.column >= 0 && point.column < graphicWidth else { continue }
                    let cell = point.row * graphicWidth + point.column
                    guard !nodeCells.contains(cell), canvas[point.row][point.column] != "╳",
                          canvas[point.row][point.column] != " " else { continue }
                    guard !placedArrows.contains(where: {
                        abs($0.row - point.row) <= 2 && abs($0.column - point.column) <= 3
                    }) else { continue }
                    canvas[point.row][point.column] = request.glyph
                    placedArrows.append(point)
                    break
                }
            }
            var labelled = Set(diagram.edges.compactMap { edge in
                (edgeLabels[edge.id] ?? "").isEmpty ? edge.id : nil
            })
            for text in edgeTexts {
                guard !text.text.isEmpty else {
                    labelled.insert(text.id)
                    continue
                }
                let midpoint = (text.firstRow + text.lastRow) / 2
                let rows = ((text.firstRow + 1)..<text.lastRow).sorted { a, b in
                    let distanceA = abs(a - midpoint)
                    let distanceB = abs(b - midpoint)
                    return distanceA == distanceB ? a < b : distanceA < distanceB
                }
                for row in rows {
                    if draw(text.text, row: row, column: text.column + 2,
                            canvas: &canvas, ifFree: true) ||
                       draw(text.text, row: row, column: text.column - text.text.count - 2,
                            canvas: &canvas, ifFree: true) {
                        labelled.insert(text.id)
                        break
                    }
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
            var lines = canvas.map { row in
                guard let last = row.lastIndex(where: { $0 != " " }) else { return "" }
                return String(row[...last])
            }
            if axisWidth > 0 {
                for row in lines.indices {
                    let label = row % step == 0 ? rowLabels[row / step] : ""
                    let padding = String(repeating: " ", count: axisWidth - label.count + 2)
                    lines[row] = label + padding + lines[row]
                }
            }
            // Edge details remain available even where cramped crossings prevent labels.
            for edge in diagram.edges where !labelled.contains(edge.id) {
                let line = "edge \(edge.id): \(edge.source) -> \(edge.destination) [\(edgeLabels[edge.id] ?? "")]"
                lines += TerminalTextLayout(text: line, columns: available).rows.map(\.content)
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
