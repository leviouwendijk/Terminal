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
        case relocationPresentation
        case movementReasons
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

        let narrowRegion = TerminalRegion(rows: 20, columns: 9)
        let narrowTree = TerminalDifferenceRenderer.render(
            layout,
            options: TerminalDifferenceRenderOptions().constrained(to: narrowRegion)
        )
        guard narrowTree.components(separatedBy: "\n").allSatisfy({
            TerminalDisplay.width(of: $0) <= narrowRegion.columns
        }) else {
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

        let relocationLayout = TreeDifferenceLayout(lines: [
            .init(
                depth: 0,
                is_last_child: false,
                ancestor_last: [],
                change: .moved,
                label: "moved.swift",
                id: "relocated",
                relocation: .init(
                    from: "A/moved.swift",
                    to: "B/moved.swift"
                )
            ),
            .init(
                depth: 0,
                is_last_child: true,
                ancestor_last: [],
                change: .moved_modified,
                label: "changed.swift",
                id: "relocated-modified",
                relocation: .init(
                    from: "A/changed.swift",
                    to: "B/changed.swift"
                )
            ),
        ])
        let relocationPlain = TerminalDifferenceRenderer.render(
            relocationLayout,
            options: plain_options
        )
        let canonicalRelocation = TreeDifferenceRenderer.render(
            TreeDifferenceRenderPlan.make(relocationLayout)
        )
        guard relocationPlain == canonicalRelocation,
              relocationPlain.contains("A/moved.swift -> B/moved.swift"),
              relocationPlain.contains("A/changed.swift -> B/changed.swift") else {
            throw Failure.relocationPresentation
        }

        let relocationColored = TerminalDifferenceRenderer.render(
            relocationLayout
        ).components(separatedBy: "\n")
        guard relocationColored.count == 2,
              relocationColored[0].contains("\u{001B}[36mA/moved.swift"),
              relocationColored[0].contains("\u{001B}[90m -> "),
              relocationColored[0].contains("\u{001B}[36mB/moved.swift"),
              relocationColored[1].contains("\u{001B}[35mA/changed.swift"),
              relocationColored[1].contains("\u{001B}[90m -> "),
              relocationColored[1].contains("\u{001B}[35mB/changed.swift") else {
            throw Failure.relocationPresentation
        }

        let movement_layout = TreeDifferenceLayout(lines: [
            .init(
                depth: 0, is_last_child: false, ancestor_last: [],
                change: .moved, label: "execute()", id: "execute",
                movement_reasons: [.reordered]
            ),
            .init(
                depth: 0, is_last_child: true, ancestor_last: [],
                change: .moved_modified, label: "persist()", id: "persist",
                movement_reasons: [.relocated, .reparented]
            ),
        ])
        let annotated = TreeDifferenceRenderer.render(
            TreeDifferenceRenderPlan.make(movement_layout, show_movement_reasons: true)
        )
        let unannotated = TreeDifferenceRenderer.render(
            TreeDifferenceRenderPlan.make(movement_layout)
        )
        guard annotated == "> execute()  [reordered]\n* persist()  [relocated, reparented]",
              unannotated == "> execute()\n* persist()",
              TerminalDifferenceRenderer.render(movement_layout, options: plain_options) == annotated,
              TerminalDifferenceRenderer.render(
                  movement_layout,
                  options: .init(style: plain_style, show_movement_reasons: false)
              ) == unannotated else {
            throw Failure.movementReasons
        }
        let movement_colored = TerminalDifferenceRenderer.render(movement_layout)
            .components(separatedBy: "\n")
        guard movement_colored.count == 2,
              movement_colored[0].contains("\u{001B}[36mreordered"),
              movement_colored[0].contains("\u{001B}[90m  ["),
              movement_colored[1].contains("\u{001B}[35mrelocated, reparented"),
              movement_colored[1].contains("\u{001B}[90m]") else {
            throw Failure.movementReasons
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
