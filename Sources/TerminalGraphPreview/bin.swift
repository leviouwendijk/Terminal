import Primitives
import Terminal
import TerminalGraph

@main
struct TerminalGraphPreview {
    enum PreviewError: Error {
        case invalidArgument(String)
    }

    enum Mode: String {
        case all
        case braid
        case dag
    }

    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        var columns = max(1, Terminal.size(for: .standardOutput).columns)
        var mode: Mode = .all
        var index = 0

        while index < arguments.count {
            switch arguments[index] {
            case "--columns":
                index += 1
                guard index < arguments.count,
                      let value = Int(arguments[index]), value > 0 else {
                    throw PreviewError.invalidArgument("--columns requires a positive integer")
                }
                columns = value
            case "--mode":
                index += 1
                guard index < arguments.count,
                      let value = Mode(rawValue: arguments[index]) else {
                    throw PreviewError.invalidArgument("--mode must be all, braid, or dag")
                }
                mode = value
            case "--help":
                print("Usage: graphpreview [--columns N] [--mode all|braid|dag]")
                return
            default:
                throw PreviewError.invalidArgument("Unknown option: \(arguments[index])")
            }
            index += 1
        }

        if mode == .all || mode == .braid {
            try braid(columns: columns)
        }
        if mode == .all || mode == .dag {
            try dag(columns: columns)
        }
    }

    static func braid(columns: Int) throws {
        typealias G = Graph<String, String, String, String>
        typealias D = GraphDiagram<String, String>
        let ids = ["cycle_open", "P1", "I1", "P2", "I2", "P3", "I3", "gate", "reset_gate"]
        let connections: [(String, String, String)] = [
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
            edges: connections.map {
                .init(id: $0.0, source: $0.1, destination: $0.2, value: "")
            }
        )
        let positions = Dictionary(uniqueKeysWithValues: ids.enumerated().map { index, id in
            (id, D.Point(row: index, lane: [1, 0, 2, 0, 2, 0, 2, 1, 1][index]))
        })
        let diagram = try graph.diagram(positions: positions)
        let result = TerminalGraph.DiagramRenderer().project(
            diagram, columns: columns, label: { $0 },
            edgeLabel: { $0 == "c1" || $0 == "c2" ? "24h" : "3h" }
        )
        print("BRAID / \(columns) COLUMNS / \(diagram.nodes.count) NODES / \(diagram.edges.count) EDGES")
        print(result.lines.joined(separator: "\n"))
        if result.lines.contains(where: { $0.contains("╳") }) {
            print("╳ = crossing without a graph junction")
        }
        print("")
    }

    static func dag(columns: Int) throws {
        typealias G = Graph<String, String, String, String>
        let graph = try G(
            nodes: ["A", "B", "C", "D", "E"].map { .init(id: $0, value: $0) },
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
        let result = TerminalGraph.Renderer().project(
            layout, columns: columns, label: { "node \($0)" }
        )
        print("DAG / \(columns) COLUMNS / \(layout.nodes.count) NODES / \(layout.edges.count) EDGES")
        print(result.lines.joined(separator: "\n"))
    }
}
