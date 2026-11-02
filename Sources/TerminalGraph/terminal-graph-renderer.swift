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
                        let dr = b.row == a.row ? 0 : (b.row > a.row ? 1 : -1)
                        let dc = b.col == a.col ? 0 : (b.col > a.col ? 1 : -1)
                        let steps = max(abs(b.row - a.row), abs(b.col - a.col))
                        for step in 0..<steps {
                            let r = a.row + dr * step
                            let c = a.col + dc * step
                            let nr = r + dr
                            let nc = c + dc
                            let bits: UInt8 = dr > 0 ? 4 : dr < 0 ? 1 : dc > 0 ? 2 : 8
                            let reverse: UInt8 = dr > 0 ? 1 : dr < 0 ? 4 : dc > 0 ? 8 : 2
                            grid[r][c] |= bits
                            grid[nr][nc] |= reverse
                        }
                    }
                    let first = edge.points.first?.row ?? 0
                    let last = edge.points.last?.row ?? 0
                    edgeRows[edge.id] = (first * 2)..<(last * 2 + 1)
                }
                var nodesByRow: [Int: GraphLayout<NodeID, EdgeID>.Node] = [:]
                for node in layout.nodes { nodesByRow[node.position.row * 2] = node }
                for row in 0..<height {
                    var glyphs = grid[row].map(glyph)
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

        private func glyph(_ mask: UInt8) -> Character {
            switch mask {
            case 1: "╵"
            case 2: "╶"
            case 3: "└"
            case 4: "╷"
            case 5: "│"
            case 6: "┌"
            case 7: "├"
            case 8: "╴"
            case 9: "┘"
            case 10: "─"
            case 11: "┴"
            case 12: "┐"
            case 13: "┤"
            case 14: "┬"
            case 15: "┼"
            default: " "
            }
        }
    }
}
