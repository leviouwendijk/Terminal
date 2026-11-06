import Difference
import Foundation
import Terminal

enum TerminalGraphDifferenceSmoke {
    enum Failure: Error {
        case missingNodeChange
        case missingEdgeChange
        case missingBeforeAfter
        case incorrectUnchangedVisibility
        case missingCombinedProjection
        case unescapedControl
        case incorrectlyClipped
    }

    static func run() throws {
        let graph = GraphDifferenceLayout(
            nodes: [
                .init(
                    id: "lan",
                    change: .modified,
                    before: .init(label: "LAN", detail: "original subnet"),
                    after: .init(label: "LAN", detail: "revised subnet")
                ),
                .init(
                    id: "wan",
                    change: .unchanged,
                    before: .init(label: "WAN"),
                    after: .init(label: "WAN")
                ),
                .init(
                    id: "guest",
                    change: .added,
                    before: nil,
                    after: .init(label: "Guest", detail: "VLAN 30")
                ),
            ],
            edges: [
                .init(
                    id: "policy",
                    change: .modified,
                    before: .init(
                        endpoints: .init(source: "lan", destination: "wan"),
                        presentation: .init(label: "allow", detail: "tcp:443")
                    ),
                    after: .init(
                        endpoints: .init(source: "guest", destination: "wan"),
                        presentation: .init(label: "deny", detail: "tcp:443")
                    )
                ),
            ]
        )
        let plainStyle = TerminalDifferenceStyle(
            header: .none, lineNumbers: .none, border: .none,
            equal: .none, insert: .none, delete: .none,
            modified: .none, moved: .none, moved_modified: .none,
            separator: .none
        )
        let options = TerminalDifferenceRenderOptions(style: plainStyle)
        let rendered = TerminalDifferenceRenderer.render(graph, options: options)
        guard rendered.contains("Nodes"), rendered.contains("~ [lan]"),
              rendered.contains("+ [guest]"), rendered.contains("original subnet"),
              rendered.contains("revised subnet") else {
            throw Failure.missingNodeChange
        }
        guard rendered.contains("Edges"), rendered.contains("~ [policy]"),
              rendered.contains("lan ──▶ wan"), rendered.contains("guest ──▶ wan") else {
            throw Failure.missingEdgeChange
        }
        guard rendered.contains("before"), rendered.contains("after"),
              rendered.contains("allow"), rendered.contains("deny") else {
            throw Failure.missingBeforeAfter
        }
        guard !rendered.contains("[wan]") else {
            throw Failure.incorrectUnchangedVisibility
        }
        let all = TerminalDifferenceRenderer.render(
            graph,
            options: .init(
                base: .init(showUnchangedLines: true),
                style: plainStyle
            )
        )
        guard all.contains("[wan]") else {
            throw Failure.incorrectUnchangedVisibility
        }
        let text = DifferenceLayout(lines: [.init(role: .insert, text: "text_marker")])
        let tree = TreeDifferenceLayout(lines: [
            .init(
                depth: 0,
                is_last_child: true,
                ancestor_last: [],
                change: .modified,
                label: "tree_marker",
                id: "root"
            ),
        ])
        let combined = TerminalDifferenceRenderer.render(
            DifferencePresentation(text: text, tree: tree, graph: graph),
            options: options
        )
        guard combined.contains("text_marker"), combined.contains("tree_marker"),
              combined.contains("[policy]") else {
            throw Failure.missingCombinedProjection
        }
        let malicious = GraphDifferenceLayout(
            nodes: [
                .init(
                    id: "unsafe",
                    change: .added,
                    before: nil,
                    after: .init(label: "name\u{001B}[31m")
                ),
            ],
            edges: []
        )
        let safe = TerminalDifferenceRenderer.render(malicious, options: options)
        guard !safe.contains("\u{001B}"), safe.contains("\\u{1B}") else {
            throw Failure.unescapedControl
        }
        let wrapped = TerminalDifferenceRenderer.render(
            graph,
            options: .init(style: plainStyle, columns: 12)
        )
        let unfolded = wrapped.replacingOccurrences(of: "\n", with: "")
        guard unfolded.contains("revised"), unfolded.contains("tcp:443") else {
            throw Failure.incorrectlyClipped
        }
        print("terminal graph difference smoke passed")
    }
}
