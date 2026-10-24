import Difference
import Foundation
import Terminal

enum TerminalStructuredDifferenceSmoke {
    enum Failure: Error {
        case treeGeometry
        case changeStyles
        case contentOnlyTreeChange
        case viewSelection
        case textOptions
        case treeOnlyFormatting
        case semanticMutation
    }

    static func run() throws {
        let layout = TreeDifferenceLayout(lines: [
            .init(depth: 0, is_last_child: true, ancestor_last: [], change: .unchanged, label: "Sources/", id: "root"),
            .init(depth: 1, is_last_child: false, ancestor_last: [true], change: .added, label: "added.swift", id: "added"),
            .init(depth: 1, is_last_child: false, ancestor_last: [true], change: .removed, label: "removed.swift", id: "removed"),
            .init(depth: 1, is_last_child: false, ancestor_last: [true], change: .modified, label: "changed.swift", id: "modified"),
            .init(depth: 1, is_last_child: false, ancestor_last: [true], change: .moved, label: "moved.swift", id: "moved"),
            .init(depth: 1, is_last_child: true, ancestor_last: [true], change: .moved_modified, label: "moved-edited.swift", id: "both"),
        ])
        let plain_style = TerminalDifferenceStyle(
            header: .none, lineNumbers: .none, border: .none,
            equal: .none, insert: .none, delete: .none,
            modified: .none, moved: .none, moved_modified: .none,
            separator: .none
        )
        let plain_options = TerminalDifferenceRenderOptions(style: plain_style)
        let plain = TerminalDifferenceRenderer.render(layout, options: plain_options)
        guard plain == TreeDifferenceRenderer.render(TreeDifferenceRenderPlan.make(layout)) else {
            throw Failure.treeGeometry
        }

        let colored = TerminalDifferenceRenderer.render(layout)
            .components(separatedBy: "\n")
        guard colored.count == 6,
              colored[1].contains("\u{001B}[32m"),
              colored[2].contains("\u{001B}[31m"),
              colored[3].contains("\u{001B}[33m"),
              colored[4].contains("\u{001B}[36m"),
              colored[5].contains("\u{001B}[35m") else {
            throw Failure.changeStyles
        }

        // The node does not change structurally: content alone must mark it modified.
        let structure: TreeDifference<String> = .init(
            tree: .init(roots: [
                .init(
                    .init(
                        id: "file", label: "Example.swift", change: .unchanged,
                        before: "before", after: "after"
                    ),
                    children: []
                )
            ]),
            source: .planned
        )
        let change = TextDiffer.diff(
            old: "old\n", new: "new\n",
            oldName: "Example.swift", newName: "Example.swift"
        )
        let difference = try Difference<String>(
            structure: structure,
            contents: [.init(id: "edit-1", node_id: "file", difference: change)]
        )
        let tree = TerminalDifferenceRenderer.render(
            difference, view: .tree, options: plain_options
        )
        guard tree == "~ Example.swift", difference.layout.tree.lines[0].change == .modified,
              TerminalDifferenceRenderer.render(structure, options: plain_options) == "  Example.swift" else {
            throw Failure.contentOnlyTreeChange
        }

        let options = TerminalDifferenceRenderOptions(
            base: .init(showHeader: false, showUnchangedLines: false, contextLineCount: 0),
            style: plain_style
        )
        let text = TerminalDifferenceRenderer.render(
            difference, view: .text, options: options
        )
        let combined = TerminalDifferenceRenderer.render(
            difference, view: .combined, options: options
        )
        guard text == TerminalDifferenceRenderer.render(
            difference.make_text_layout(options: options.base), options: options
        ), combined == tree + "\n\n" + text,
        TerminalDifferenceRenderer.render(difference, options: options) == combined else {
            throw Failure.viewSelection
        }
        guard !text.contains("--- Example.swift"),
              !text.contains("+++ Example.swift"),
              !text.contains("\n ") else {
            throw Failure.textOptions
        }
        guard difference.contents.count == 1,
              difference.contents[0].id == "edit-1",
              difference.structure.source == .planned else {
            throw Failure.semanticMutation
        }
        let tree_only = try Difference<String>(structure: structure)
        guard TerminalDifferenceRenderer.render(
            tree_only, options: plain_options
        ) == "  Example.swift" else {
            throw Failure.treeOnlyFormatting
        }
        Swift.print("terminal structured difference smoke passed")
    }
}
