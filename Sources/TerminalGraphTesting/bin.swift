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
        try checkBraid()
        try checkCrossings()
        try checkTemporalDiagram()
        try checkDiagonalArrowSpacing()
        try checkEdgeAwareRaster()
        print("TerminalGraph smoke: passed")
        print(wide.lines.joined(separator: "\n"))
    }

    static func checkBraid() throws {
        typealias G = Graph<String, String, String, String>
        typealias D = GraphDiagram<String, String>
        let ids = ["cycle_open", "P1", "I1", "P2", "I2", "P3", "I3", "gate", "reset_gate"]
        let links: [(String, String, String)] = [
            ("e_start", "cycle_open", "P1"),
            ("x1", "P1", "I1"), ("x2", "I1", "P2"),
            ("x3", "P2", "I2"), ("x4", "I2", "P3"),
            ("x5", "P3", "I3"), ("x6", "I3", "gate"),
            ("vP1", "P1", "P2"), ("vP2", "P2", "P3"),
            ("vI1", "I1", "I2"), ("vI2", "I2", "I3"),
            ("g1", "gate", "reset_gate"),
            ("c1", "reset_gate", "cycle_open"),
            ("c2", "reset_gate", "cycle_open"),
        ]
        let graph = try G(
            nodes: ids.map { .init(id: $0, value: $0) },
            edges: links.map { .init(id: $0.0, source: $0.1, destination: $0.2, value: "3h") }
        )
        let positions = Dictionary(uniqueKeysWithValues: ids.enumerated().map { index, id in
            (id, D.Point(row: index, lane: [1, 0, 2, 0, 2, 0, 2, 1, 1][index]))
        })
        let diagram = try graph.diagram(positions: positions)
        let renderer = TerminalGraph.DiagramRenderer()
        for columns in [1, 8, 30, 60, 100, 140] {
            let projected = renderer.project(diagram, columns: columns,
                label: { $0 }, edgeLabel: { $0 == "c1" || $0 == "c2" ? "24h" : "3h" })
            try check(projected.lines.allSatisfy { TerminalDisplay.width(of: $0) <= columns },
                      "diagram width \(columns)")
            try check(projected.nodeRows.count == 9, "diagram nodes \(columns)")
            try check(projected.edgeRows.count == 14, "diagram edges \(columns)")
            try check(projected.edgeRows["c1"] != nil && projected.edgeRows["c2"] != nil,
                      "both feedback edges \(columns)")
            if columns == 60 {
                let picture = projected.lines.joined(separator: "\n")
                try check(picture.contains("[P1]") && picture.contains("[I1]"),
                          "spatial diagram at 60 columns")
                try check(picture.contains("│") && picture.contains("─"),
                          "routed edges at 60 columns")
                try check(!picture.contains("row 0, lane 1:"),
                          "no compact fallback at 60 columns")
            }
            if columns == 140 {
                let picture = projected.lines.joined(separator: "\n")
                try check(picture.contains("[P1]") && picture.contains("[I1]"), "spatial labels")
                try check(picture.contains("│") && picture.contains("─"), "orthogonal routes")
                try check(picture.contains("24h"), "feedback label")
                try check(projected.nodeRows["P1"] != projected.nodeRows["I1"], "alternating rows")
                func column(of id: String) throws -> Int {
                    guard let row = projected.nodeRows[id],
                          let range = projected.lines[row].range(of: "[\(id)]") else {
                        throw SmokeError.failed("Missing positioned node \(id)")
                    }
                    return projected.lines[row].distance(
                        from: projected.lines[row].startIndex, to: range.lowerBound
                    )
                }
                let p1 = try column(of: "P1")
                let p2 = try column(of: "P2")
                let i1 = try column(of: "I1")
                let i2 = try column(of: "I2")
                let cycle = try column(of: "cycle_open")
                try check(p1 == p2 && i1 == i2, "stable spatial lanes")
                try check(p1 > 0 && p1 < cycle && cycle < i1, "leading padding preserved")
                try check(!picture.contains("edge vI1:") && !picture.contains("edge vI2:"),
                          "same-lane labels placed within graph")
            }
        }
    }

    static func checkCrossings() throws {
        typealias D = GraphDiagram<String, String>
        func point(_ row: Int, _ lane: Int) -> D.Point {
            .init(row: row, lane: lane)
        }

        let crossing = try D(
            nodes: [
                .init(id: "A", position: point(0, 0)),
                .init(id: "C", position: point(0, 2)),
                .init(id: "D", position: point(2, 0)),
                .init(id: "B", position: point(2, 2)),
            ],
            edges: [
                .init(
                    id: "horizontal", source: "A", destination: "B",
                    points: [point(0, 0), point(1, 0), point(1, 2), point(2, 2)]
                ),
                .init(
                    id: "vertical", source: "C", destination: "D",
                    points: [point(0, 2), point(0, 1), point(2, 1), point(2, 0)]
                ),
            ]
        )
        let renderer = TerminalGraph.DiagramRenderer()
        let crossed = renderer.project(
            crossing, columns: 60, label: { $0 }, edgeLabel: { _ in "" }
        )
        let picture = crossed.lines.joined(separator: "\n")
        try check(picture.filter { $0 == "╳" }.count == 1,
                  "independent through-routes have one crossing marker")
        try check(crossed.edgeRows.count == 2,
                  "crossing preserves both edge identities")
        try check(crossed.lines.allSatisfy { TerminalDisplay.width(of: $0) <= 60 },
                  "crossing respects terminal width")

        let bend = try D(
            nodes: [
                .init(id: "A", position: point(0, 0)),
                .init(id: "B", position: point(1, 1)),
            ],
            edges: [
                .init(
                    id: "bend", source: "A", destination: "B",
                    points: [point(0, 0), point(0, 1), point(1, 1)]
                ),
            ]
        )
        let bent = renderer.project(
            bend, columns: 60, label: { $0 }, edgeLabel: { _ in "" }
        )
        try check(!bent.lines.joined(separator: "\n").contains("╳"),
                  "single-edge bends are not crossings")
    }

    static func checkTemporalDiagram() throws {
        typealias D = GraphDiagram<String, String>
        let p1 = D.Point(row: 0, lane: 0)
        let i1 = D.Point(row: 1, lane: 2)
        let p2 = D.Point(row: 2, lane: 0)
        let diagram = try D(
            nodes: [
                .init(id: "P1", position: p1),
                .init(id: "I1", position: i1),
                .init(id: "P2", position: p2)
            ],
            edges: [
                .init(id: "x1", source: "P1", destination: "I1", points: [p1, i1]),
                .init(id: "x2", source: "I1", destination: "P2", points: [i1, p2]),
                .init(id: "vP1", source: "P1", destination: "P2", points: [p1, p2])
            ]
        )
        let projected = TerminalGraph.DiagramRenderer().project(
            diagram,
            columns: 80,
            label: { $0 },
            edgeLabel: { $0 == "vP1" ? "6h" : "3h" },
            rowLabel: { row in ["t+0h", "t+3h", "t+6h"][row] }
        )
        let picture = projected.lines.joined(separator: "\n")
        try check(picture.contains("t+0h") && picture.contains("t+3h") &&
                  picture.contains("t+6h"), "time axis labels")
        let braille = picture.unicodeScalars.filter { (0x2801...0x28ff).contains(Int($0.value)) }
        try check(braille.count >= 4, "continuous subcell diagonals")
        try check(picture.contains("[P1]") && picture.contains("[I1]") &&
                  picture.contains("[P2]"), "timeline node identities")
        try check(projected.edgeRows.count == 3, "diagonal and vertical edge identities")
        try check(projected.lines.allSatisfy { TerminalDisplay.width(of: $0) <= 80 },
                  "time axis respects available width")
    }

    static func checkDiagonalArrowSpacing() throws {
        typealias D = GraphDiagram<String, String>
        let p1 = D.Point(row: 0, lane: 0)
        let i1 = D.Point(row: 1, lane: 1)
        let p2 = D.Point(row: 2, lane: 0)
        let diagram = try D(
            nodes: [
                .init(id: "P1", position: p1),
                .init(id: "I1", position: i1),
                .init(id: "P2", position: p2),
            ],
            edges: [
                .init(id: "x1", source: "P1", destination: "I1", points: [p1, i1]),
                .init(id: "x2", source: "I1", destination: "P2", points: [i1, p2]),
                .init(id: "vP1", source: "P1", destination: "P2", points: [p1, p2]),
            ]
        )
        let renderer = TerminalGraph.DiagramRenderer()
        for columns in [60, 80, 100, 140] {
            let visible = renderer.project(
                diagram, columns: columns, label: { $0 }, edgeLabel: { _ in "" },
                rowLabel: { ["t+0h", "t+3h", "t+6h"][$0] }
            )
            let picture = visible.lines.joined(separator: "\n")
            let braille = picture.unicodeScalars.filter { (0x2801...0x28ff).contains(Int($0.value)) }
            try check(braille.count >= 4, "subcell diagonal paths at \(columns)")
            try check(picture.contains("↙") && picture.contains("▼"),
                      "both incoming arrows survive at \(columns)")
            let arrows: [(row: Int, column: Int)] = visible.lines.enumerated().flatMap { row, line in
                line.enumerated().compactMap { column, glyph in
                    "↙▼".contains(glyph) ? (row: row, column: column) : nil
                }
            }
            try check(arrows.count == 2, "exactly two incoming arrowheads at \(columns)")
            if arrows.count == 2 {
                try check(abs(arrows[0].row - arrows[1].row) > 2 ||
                          abs(arrows[0].column - arrows[1].column) > 3,
                          "incoming arrowheads remain separated at \(columns)")
            }
            try check(visible.nodeRows.count == 3 && visible.edgeRows.count == 3,
                      "node and edge identities preserved at \(columns)")
            try check(visible.lines.allSatisfy { TerminalDisplay.width(of: $0) <= columns },
                      "diagram respects width \(columns)")
        }
        let narrow = renderer.project(
            diagram, columns: 12, label: { $0 }, edgeLabel: { _ in "" },
            rowLabel: { ["t+0h", "t+3h", "t+6h"][$0] }
        )
        let narrowText = narrow.lines.joined(separator: "")
        try check(narrowText.contains("t+3h") && narrowText.contains("t+6h"),
                  "compact fallback preserves row labels")
        try check(narrow.lines.allSatisfy { TerminalDisplay.width(of: $0) <= 12 },
                  "compact fallback respects width")
    }

    static func checkEdgeAwareRaster() throws {
        typealias D = GraphDiagram<String, String>
        func point(_ row: Int, _ lane: Int) -> D.Point {
            .init(row: row, lane: lane)
        }
        let diagram = try D(
            nodes: [
                .init(id: "A", position: point(0, 0)),
                .init(id: "B", position: point(2, 2)),
                .init(id: "C", position: point(0, 2)),
                .init(id: "D", position: point(2, 0))
            ],
            edges: [
                .init(id: "down", source: "A", destination: "B",
                      points: [point(0, 0), point(2, 2)]),
                .init(id: "up", source: "C", destination: "D",
                      points: [point(0, 2), point(2, 0)])
            ]
        )
        let renderer = TerminalGraph.DiagramRenderer()
        let projected = renderer.project(diagram, columns: 80,
                                         label: { $0 }, edgeLabel: { _ in "" })
        let picture = projected.lines.joined(separator: "\n")
        try check(picture.filter { $0 == "╳" }.count == 1,
                  "independent diagonals cross once without joining")
        try check(projected.edgeRows.count == 2 && projected.nodeRows.count == 4,
                  "diagonal intersection preserves identities")

        let branch = try D(
            nodes: [
                .init(id: "I1", position: point(0, 1)),
                .init(id: "I2", position: point(2, 1)),
                .init(id: "P2", position: point(1, 0))
            ],
            edges: [
                .init(id: "repeat", source: "I1", destination: "I2",
                      points: [point(0, 1), point(2, 1)]),
                .init(id: "alternate", source: "I1", destination: "P2",
                      points: [point(0, 1), point(1, 0)])
            ]
        )
        let forked = renderer.project(branch, columns: 80,
                                      label: { $0 }, edgeLabel: { _ in "" })
        try check(!forked.lines.joined(separator: "\n").contains("╳"),
                  "branches sharing a nearby source are not false crossings")
    }

    static func check(_ value: @autoclosure () -> Bool, _ message: String) throws {
        guard value() else { throw SmokeError.failed(message) }
    }
}
