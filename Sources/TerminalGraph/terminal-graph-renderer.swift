import Foundation
import Primitives
import Terminal

/// A read-only multi-lane renderer. It never changes canonical graph ordering.
public enum TerminalGraph {
    public struct Projection<NodeID: Hashable, EdgeID: Hashable, ReferenceID: Hashable> {
        public let lines: [String]
        public let nodeRows: [NodeID: Int]
        public let edgeRows: [EdgeID: Range<Int>]
        public let referenceRows: [ReferenceID: Int]

        public init(
            lines: [String],
            nodeRows: [NodeID: Int],
            edgeRows: [EdgeID: Range<Int>],
            referenceRows: [ReferenceID: Int]
        ) {
            self.lines = lines
            self.nodeRows = nodeRows
            self.edgeRows = edgeRows
            self.referenceRows = referenceRows
        }
    }

    public struct Renderer: Sendable {
        public init() {}

        public func project<NodeID: Hashable, EdgeID: Hashable>(
            _ layout: GraphLayout<NodeID, EdgeID>,
            columns: Int,
            label: (NodeID) -> String
        ) -> Projection<NodeID, EdgeID, String> {
            let empty: [GraphLayout<NodeID, EdgeID>.ReferencePlacement<String>] = []
            return project(layout, columns: columns, label: label,
                           references: empty, referenceLabel: { $0 })
        }

        public func project<NodeID: Hashable, EdgeID: Hashable, ReferenceID: Hashable>(
            _ layout: GraphLayout<NodeID, EdgeID>,
            columns: Int,
            label: (NodeID) -> String,
            references: [GraphLayout<NodeID, EdgeID>.ReferencePlacement<ReferenceID>],
            referenceLabel: (ReferenceID) -> String
        ) -> Projection<NodeID, EdgeID, ReferenceID> {
            let width = max(1, columns)
            let graphWidth = layout.lane_count * 4 - (layout.lane_count > 0 ? 3 : 0)
            let compact = graphWidth + 10 > width
            var nodeRows: [NodeID: Int] = [:]
            var edgeRows: [EdgeID: Range<Int>] = [:]
            var referenceRows: [ReferenceID: Int] = [:]
            var lines: [String] = []
            var refsByTarget: [NodeID: [(ReferenceID, String)]] = [:]
            for reference in references where reference.position != nil {
                refsByTarget[reference.target, default: []].append(
                    (reference.id, clean(referenceLabel(reference.id)))
                )
            }

            if compact {
                for node in layout.nodes {
                    let tags = refsByTarget[node.id, default: []].map(\.1)
                    let suffix = tags.isEmpty ? "" : " [" + tags.joined(separator: ", ") + "]"
                    let text = "\(node.position.row) (lane \(node.position.lane)): \(clean(label(node.id)))\(suffix)"
                    nodeRows[node.id] = lines.count
                    for reference in refsByTarget[node.id, default: []] {
                        referenceRows[reference.0] = lines.count
                    }
                    lines += wrap(text, width: width)
                }
                for edge in layout.edges {
                    let detail = wrap("edge \(edge.id): \(edge.source) -> \(edge.destination)", width: width)
                    edgeRows[edge.id] = lines.count..<(lines.count + detail.count)
                    lines += detail
                }
            } else if !layout.nodes.isEmpty {
                let height = layout.nodes.count * 2 - 1
                var grid = Array(
                    repeating: Array(repeating: UInt8(0), count: graphWidth),
                    count: height
                )
                for edge in layout.edges {
                    let points = edge.points.map { (row: $0.row * 2, col: $0.lane * 4) }
                    for (a, b) in zip(points, points.dropFirst()) {
                        TerminalGraphStroke.trace(
                            from: .init(row: a.row, column: a.col),
                            to: .init(row: b.row, column: b.col),
                            into: &grid
                        )
                    }
                    let first = edge.points.first?.row ?? 0
                    let last = edge.points.last?.row ?? 0
                    edgeRows[edge.id] = (first * 2)..<(last * 2 + 1)
                }
                var nodesByRow: [Int: GraphLayout<NodeID, EdgeID>.Node] = [:]
                for node in layout.nodes { nodesByRow[node.position.row * 2] = node }
                for row in 0..<height {
                    var glyphs = grid[row].map(TerminalGraphStroke.glyph)
                    if let node = nodesByRow[row] {
                        glyphs[node.position.lane * 4] = "●"
                    }
                    var line = String(glyphs)
                    if let node = nodesByRow[row] {
                        let tags = refsByTarget[node.id, default: []].map(\.1)
                        let suffix = tags.isEmpty ? "" : " [" + tags.joined(separator: ", ") + "]"
                        line += "  " + fit(clean(label(node.id)) + suffix, width: width - graphWidth - 2)
                        nodeRows[node.id] = lines.count
                        for reference in refsByTarget[node.id, default: []] {
                            referenceRows[reference.0] = lines.count
                        }
                    }
                    lines.append(TerminalDisplay.clipped(line, columns: width))
                }
            }

            for reference in references where reference.position == nil {
                referenceRows[reference.id] = lines.count
                lines += wrap("unplaced reference \(clean(referenceLabel(reference.id))) -> \(reference.target)", width: width)
            }
            if lines.isEmpty { lines = [fit("(empty graph)", width: width)] }
            return Projection(
                lines: lines, nodeRows: nodeRows, edgeRows: edgeRows,
                referenceRows: referenceRows
            )
        }

        public func rows<NodeID: Hashable, EdgeID: Hashable>(
            _ layout: GraphLayout<NodeID, EdgeID>,
            columns: Int,
            label: (NodeID) -> String
        ) -> [String] {
            project(layout, columns: columns, label: label).lines
        }

        public func render<NodeID: Hashable, EdgeID: Hashable>(
            _ layout: GraphLayout<NodeID, EdgeID>,
            columns: Int,
            label: (NodeID) -> String
        ) -> String {
            rows(layout, columns: columns, label: label).joined(separator: "\n")
        }

        private func clean(_ text: String) -> String {
            text.replacingOccurrences(of: "\r", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
        }

        private func fit(_ text: String, width: Int) -> String {
            let available = max(1, width)
            if TerminalDisplay.width(of: text) <= available { return text }
            if available == 1 { return TerminalDisplay.clipped(text, columns: 1) }
            return TerminalDisplay.clipped(text, columns: available - 1) + "…"
        }

        private func wrap(_ text: String, width: Int) -> [String] {
            TerminalTextLayout(text: text, columns: width).rows.map(\.content)
        }


    }
}
