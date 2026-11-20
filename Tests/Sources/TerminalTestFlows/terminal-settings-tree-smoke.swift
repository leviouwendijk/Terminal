import Foundation
import Primitives
import Terminal

enum TerminalSettingsTreeSmoke {
    enum Failure: Error {
        case navigation
        case events
        case render
    }

    static func run() throws {
        typealias Node = Tree<TerminalSettingsTreeEntry<String>>.Node
        let tree = Tree(roots: [
            Node(.init(id: "model", title: "Model", value: "fast"), children: [
                Node(.init(id: "fast", title: "fast", accessory: .radio(selected: true))),
                Node(.init(id: "slow", title: "slow", accessory: .radio(selected: false), isEnabled: false)),
            ]),
            Node(.init(id: "capabilities", title: "Capabilities"), children: [
                Node(.init(id: "core", title: "Core"), children: [
                    Node(.init(
                        id: "mutate",
                        title: "mutate_files",
                        accessory: .indicators(first: true, second: false),
                        detail: .init(title: "mutate_files", fields: [.init("visibility", "hidden")])
                    )),
                ]),
            ]),
        ])
        var control = TerminalSettingsTreeControl(
            title: "Settings",
            tree: tree,
            collapsed: ["model", "capabilities"],
            legends: ["capabilities": "A V"]
        )
        guard control.list.rows.map(\.item.id) == ["model", "capabilities"] else { throw Failure.navigation }

        // Enter folds a section open in place; a disabled choice is refused.
        _ = control.handle(.enter)
        _ = control.handle(.char("j"))
        _ = control.handle(.char("j"))
        guard control.breadcrumb == "Settings / Model",
              control.handle(.enter) == .unavailable("slow") else { throw Failure.events }
        _ = control.handle(.char("k"))
        guard control.handle(.enter) == .accepted("fast") else { throw Failure.events }

        // `/` reaches settings in folded sections; Space is a second switch.
        for key in [TerminalKey.char("/")] + "mutate".map({ .char(String($0)) }) + [.enter] {
            _ = control.handle(key)
        }
        guard control.currentID == "mutate",
              control.breadcrumb == "Settings / Capabilities / Core",
              control.handle(.space) == .toggled("mutate") else { throw Failure.events }

        var frame = TerminalFrame(rows: 24, columns: 80)
        control.render(into: &frame, in: TerminalRegion(rows: 24, columns: 80))
        let text = frame.resolved().spans.map(\.content).joined(separator: "\n")
            .replacingOccurrences(of: #"\u{1B}\[[0-9;]*m"#, with: "", options: .regularExpression)
        guard text.contains("Settings / Capabilities / Core"),
              text.contains("A V"),
              text.contains("[● ○] mutate_files"),
              text.contains("visibility"),
              text.contains("/mutate") else { throw Failure.render }

        // Esc clears the filter first, then closes; q always closes.
        _ = control.handle(.escape)
        guard control.list.query.isEmpty,
              control.handle(.escape) == .closeRequested,
              control.handle(.char("q")) == .closeRequested else { throw Failure.events }
    }
}
