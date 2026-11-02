import Foundation
import Primitives
import Terminal
import TerminalGraph

private enum SmokeError: Error {
    case failed(String)
}

@main
struct TerminalGraphSmoke {
    static func main() throws {
        typealias G = Graph<String, String, String, String>
        let graph = try G(
            nodes: [
                .init(id: "A", value: "Root"),
                .init(id: "B", value: "Branch one"),
                .init(id: "C", value: "Branch two"),
                .init(id: "D", value: "Merge"),
                .init(id: "E", value: "Detached"),
            ],
            edges: [
                .init(id: "ab", source: "A", destination: "B", value: "ancestry"),
                .init(id: "ac", source: "A", destination: "C", value: "ancestry"),
                .init(id: "bd", source: "B", destination: "D", value: "ancestry"),
                .init(id: "cd", source: "C", destination: "D", value: "ancestry"),
                .init(id: "da", source: "D", destination: "A", value: "annotation"),
            ]
        )
        let layout = try graph.layout(
            order: ["A", "B", "C", "D", "E"],
            including_edges: { $0.value == "ancestry" }
        )
        let references = try ReferenceSet<String, String>(references: [
            .init(id: "main", target: "D"),
            .init(id: "feature", target: "C"),
            .init(id: "unloaded", target: "outside"),
        ])
        let renderer = TerminalGraph.Renderer()
        let wide = renderer.project(
            layout, columns: 90, label: { "node \($0)" },
            references: layout.place_references(references), referenceLabel: { $0 }
        )
        try check(wide.lines.joined(separator: "\n").contains("●"), "Node glyph")
        try check(wide.lines.joined(separator: "\n").contains("│"), "Vertical connector")
        try check(wide.lines.joined(separator: "\n").contains("─"), "Horizontal connector")
        try check(wide.lines.joined(separator: "\n").contains("[main]"), "Reference label")
        try check(wide.lines.joined(separator: "\n").contains("unplaced reference unloaded"), "Unplaced reference")
        try check(wide.nodeRows["A"] == 0 && wide.nodeRows["D"] == 6, "Stable node rows")
        try check(wide.edgeRows["cd"] == 4..<7, "Stable edge row range")
        try check(wide.referenceRows["main"] == wide.nodeRows["D"], "Reference row")
        try check(wide.referenceRows["unloaded"] != nil, "Unplaced reference row")
        for width in [1, 8, 16, 28, 90] {
            let projected = renderer.project(layout, columns: width, label: { "node \($0)" },
                references: layout.place_references(references), referenceLabel: { $0 })
            try check(projected.lines.allSatisfy { TerminalDisplay.width(of: $0) <= width }, "Width \(width)")
            try check(projected.nodeRows.count == layout.nodes.count, "All nodes \(width)")
            try check(projected.edgeRows.count == layout.edges.count, "All edges \(width)")
            try check(projected.referenceRows.count == references.references.count, "All references \(width)")
        }
        let reversed = try graph.layout(
            orientation: .destination_first,
            including_edges: { $0.value == "ancestry" }
        )
        let reversedProjection = renderer.project(reversed, columns: 90, label: { $0 })
        try check(reversedProjection.nodeRows.count == 5, "Reverse orientation")
        let empty = try G(nodes: [], edges: []).layout()
        try check(renderer.render(empty, columns: 15, label: { $0 }) == "(empty graph)", "Empty")
        print("TerminalGraph smoke: passed")
        print(wide.lines.joined(separator: "\n"))
    }

    static func check(_ value: @autoclosure () -> Bool, _ message: String) throws {
        guard value() else { throw SmokeError.failed(message) }
    }
}
