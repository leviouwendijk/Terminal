import Primitives
import Terminal
import Testing

private struct Entry: Sendable {
    var id: Int
    var enabled: Bool = true
}

private func list(
    _ count: Int,
    disabled: Set<Int> = [],
    current: Int? = nil
) -> TerminalListControl<Entry, Int> {
    TerminalListControl(
        items: (0..<count).map { Entry(id: $0, enabled: !disabled.contains($0)) },
        currentID: current,
        id: { $0.id },
        isEnabled: { $0.enabled }
    )
}

private func document(
    rows: Int,
    visible: Int
) -> TerminalScrollableDocument {
    TerminalScrollableDocument(
        lines: (0..<rows).map { "line \($0)" },
        visibleRows: visible
    )
}

private func tree() -> TerminalTreeList<String> {
    func leaf(_ id: String) -> Tree<TerminalTreeListItem<String>>.Node {
        .init(TerminalTreeListItem(id: id, title: id))
    }
    return TerminalTreeList(
        tree: Tree(roots: [
            .init(
                TerminalTreeListItem(id: "a", title: "a"),
                children: [leaf("a1"), leaf("a2")]
            ),
            leaf("b"),
            leaf("c"),
        ])
    )
}

enum NavigationCommandTests {
    static let suite = TestSuite("terminal navigation commands") {
        Test("default key mapping") { _ in
            try Expect.equal(TerminalNavigationCommand(key: .char("j")), .vertical(1), "j")
            try Expect.equal(TerminalNavigationCommand(key: .up), .vertical(-1), "up")
            try Expect.equal(TerminalNavigationCommand(key: .char("h")), .horizontal(-1), "h")
            try Expect.equal(TerminalNavigationCommand(key: .home), .first, "home")
            try Expect.equal(TerminalNavigationCommand(key: .pageDown), .page(1), "page down")
            try Expect.isNil(TerminalNavigationCommand(key: .char("y")), "y is not navigation")
        }

        Test("list counts clamp and never wrap") { _ in
            var control = list(10)
            try Expect.equal(control.apply(.vertical(23), pageRows: 5), .currentChanged(9), "23j to last")
            try Expect.isNil(control.apply(.vertical(4), pageRows: 5), "at end stays")
            try Expect.equal(control.apply(.vertical(-3), pageRows: 5), .currentChanged(6), "3k")
            try Expect.equal(control.apply(.vertical(Int.min), pageRows: 5), .currentChanged(0), "huge k")
        }

        Test("a single step keeps the list's wrap mode") { _ in
            var control = list(3, current: 2)
            try Expect.equal(control.apply(.vertical(1), pageRows: 5), .currentChanged(0), "j wraps")
        }

        Test("list skips disabled items and counts only enabled ones") { _ in
            var control = list(6, disabled: [1, 2])
            try Expect.equal(control.apply(.vertical(2), pageRows: 5), .currentChanged(4), "2j over disabled")
            try Expect.equal(control.apply(.position(1), pageRows: 5), .currentChanged(3), "position lands on enabled")
            try Expect.equal(control.apply(.first, pageRows: 5), .currentChanged(0), "first")
            try Expect.equal(control.apply(.last, pageRows: 5), .currentChanged(5), "last")
        }

        Test("list pages use the page size") { _ in
            var control = list(50)
            try Expect.equal(control.apply(.halfPage(1), pageRows: 10), .currentChanged(5), "ctrl-d")
            try Expect.equal(control.apply(.page(2), pageRows: 10), .currentChanged(23), "2 ctrl-f")
            try Expect.isNil(control.apply(.horizontal(1), pageRows: 10), "horizontal ignored")
        }

        Test("document scrolls by rows and pages, bounded") { _ in
            var doc = document(rows: 100, visible: 10)
            try Expect.true(doc.apply(.vertical(5)), "5j")
            try Expect.equal(doc.viewport.offset, 5, "offset 5")
            doc.apply(.halfPage(2))
            try Expect.equal(doc.viewport.offset, 15, "2 ctrl-d")
            doc.apply(.page(-1))
            try Expect.equal(doc.viewport.offset, 6, "ctrl-b")
            doc.apply(.vertical(Int.max))
            try Expect.equal(doc.viewport.offset, 90, "huge j clamps")
            try Expect.true(doc.isFollowingEnd, "at end follows")
            doc.apply(.position(40))
            try Expect.equal(doc.viewport.offset, 40, "position")
            doc.apply(.first)
            try Expect.equal(doc.viewport.offset, 0, "gg")
            try Expect.false(doc.apply(.horizontal(1)), "horizontal ignored")
        }

        Test("tree moves over visible rows and repeats h/l") { _ in
            var list = tree()
            try Expect.equal(list.rows.map(\.item.id), ["a", "a1", "a2", "b", "c"], "expanded rows")
            list.apply(.vertical(3), pageRows: 10)
            try Expect.equal(list.cursor, "b", "3j")
            list.apply(.vertical(99), pageRows: 10)
            try Expect.equal(list.cursor, "c", "clamped")
            list.apply(.position(1), pageRows: 10)
            try Expect.equal(list.cursor, "a1", "position")
            list.apply(.horizontal(-5), pageRows: 10)
            try Expect.equal(list.cursor, "a", "h to parent then collapse")
            try Expect.equal(list.rows.map(\.item.id), ["a", "b", "c"], "collapsed")
            list.apply(.horizontal(2), pageRows: 10)
            try Expect.equal(list.cursor, "a1", "2l expands then enters")
        }
    }
}
