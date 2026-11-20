import Foundation
import Primitives
import Terminal

enum TerminalTreeListSmoke {
    enum Failure: Error {
        case collapse
        case navigation
        case filter
        case ranking
        case render
    }

    static func run() throws {
        typealias Node = Tree<TerminalTreeListItem<String>>.Node
        func item(_ id: String, _ title: String) -> TerminalTreeListItem<String> {
            .init(id: id, title: title)
        }
        let tree = Tree(roots: [
            Node(item("swift", "swift_lang"), children: [
                Node(item("swift.agents", "agents"), children: [
                    Node(item("swift.implementer", "implementer")),
                    Node(item("swift.reviewer", "reviewer")),
                ]),
            ]),
            Node(item("main", "main_worker")),
        ])
        var list = TerminalTreeList(tree: tree)

        guard list.rows.map(\.item.id) == ["swift", "swift.agents", "swift.implementer", "swift.reviewer", "main"] else {
            throw Failure.collapse
        }

        // h on an expanded branch collapses it; l expands it again.
        _ = list.handle(.char("h"))
        guard list.rows.map(\.item.id) == ["swift", "main"] else { throw Failure.collapse }
        _ = list.handle(.char("l"))
        _ = list.handle(.char("j"))
        _ = list.handle(.char("j"))
        guard list.handle(.enter) == .activated("swift.implementer") else { throw Failure.navigation }
        _ = list.handle(.char("h"))
        guard list.cursor == "swift.agents" else { throw Failure.navigation }

        // / filters to matches with their ancestors.
        _ = list.handle(.char("/"))
        for character in "revw" { _ = list.handle(.char(String(character))) }
        _ = list.handle(.enter)
        guard list.rows.map(\.item.id) == ["swift", "swift.agents", "swift.reviewer"],
              list.cursor == "swift.reviewer",
              list.statusLine?.hasPrefix("/revw") == true else {
            throw Failure.filter
        }
        guard list.handle(.escape) == .queryChanged(""), list.rows.count == 5 else { throw Failure.filter }

        // Siblings rank by their best match.
        list.filter("main")
        guard list.rows.first?.item.id == "main" else { throw Failure.ranking }

        list.filter("")
        var frame = TerminalFrame(rows: 3, columns: 30)
        list.render(into: &frame, in: TerminalRegion(rows: 3, columns: 30))
        let text = frame.spans.sorted { $0.row < $1.row }.map { span in
            span.content.replacingOccurrences(
                of: "\u{1B}\\[[0-9;]*m",
                with: "",
                options: .regularExpression
            )
        }
        guard text.first?.hasPrefix("▾ swift_lang") == true,
              text.dropFirst().first?.hasPrefix("  ▾ agents") == true else {
            throw Failure.render
        }
    }
}
