import Primitives

/// One setting in a `TerminalSettingsTreeControl`: a section when its node
/// has children, else a choice, switch or read-only value.
public struct TerminalSettingsTreeEntry<ID: Hashable & Sendable>: Sendable {
    public var id: ID
    public var title: String
    /// The current value, shown dim after the title.
    public var value: String?
    public var accessory: TerminalSettingsRowAccessory
    public var isEnabled: Bool
    public var detail: TerminalSettingsDetail?
    /// What `/` matches against besides the title and value.
    public var keywords: String

    public init(
        id: ID,
        title: String,
        value: String? = nil,
        accessory: TerminalSettingsRowAccessory = .none,
        isEnabled: Bool = true,
        detail: TerminalSettingsDetail? = nil,
        keywords: String = ""
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.accessory = accessory
        self.isEnabled = isEnabled
        self.detail = detail
        self.keywords = keywords
    }
}

public enum TerminalSettingsTreeEvent<ID: Hashable & Sendable>: Sendable, Equatable {
    /// Enter on an enabled setting.
    case accepted(ID)
    /// Space on a setting.
    case toggled(ID)
    /// Enter on a disabled setting.
    case unavailable(ID)
    case closeRequested
}

/// Settings as one netrw-like tree: sections fold open in place, `/`
/// filters every setting at once, and the current one's detail shows below.
/// A value the caller owns; it rebuilds the tree whenever values change.
public struct TerminalSettingsTreeControl<ID: Hashable & Sendable>: Sendable {
    public typealias Matcher = TerminalTreeList<ID>.Matcher

    public private(set) var list: TerminalTreeList<ID>
    private var entries: [ID: TerminalSettingsTreeEntry<ID>] = [:]
    private var detailOffset = 0
    public var title: String
    /// Shown above the rows while the current row is under one of these.
    public var legends: [ID: String]
    public var instructions: String
    /// A pending count or `g`, shown in place of the instructions.
    public var pendingText: String?

    public init(
        title: String,
        tree: Tree<TerminalSettingsTreeEntry<ID>> = .init(),
        collapsed: Set<ID> = [],
        legends: [ID: String] = [:],
        instructions: String = "j/k move  h/l fold  enter select  space toggle  / filter  J/K detail  q back",
        matcher: @escaping Matcher = TerminalTreeList<ID>.subsequenceMatcher
    ) {
        self.title = title
        self.legends = legends
        self.instructions = instructions
        self.list = TerminalTreeList(collapsed: collapsed, matcher: matcher)
        update(tree)
    }

    public var currentID: ID? {
        list.cursor
    }

    public var currentEntry: TerminalSettingsTreeEntry<ID>? {
        list.cursor.flatMap { entries[$0] }
    }

    /// `Title / Section / Subsection` for the current row.
    public var breadcrumb: String {
        guard let cursor = list.cursor else { return title }
        return ([title] + list.ancestors(of: cursor).map(\.title)).joined(separator: " / ")
    }

    public mutating func update(
        _ tree: Tree<TerminalSettingsTreeEntry<ID>>
    ) {
        var entries: [ID: TerminalSettingsTreeEntry<ID>] = [:]
        let items = tree.map_values { located -> TerminalTreeListItem<ID> in
            let entry = located.node.value
            entries[entry.id] = entry
            return Self.item(entry)
        }
        self.entries = entries
        list.update(items)
    }

    public mutating func select(
        _ id: ID
    ) {
        list.select(id)
        detailOffset = 0
    }

    public mutating func filter(
        _ query: String
    ) {
        list.filter(query)
    }

    public mutating func handle(
        _ key: TerminalKey
    ) -> TerminalSettingsTreeEvent<ID>? {
        if !list.capturesInput {
            switch key {
            case .char("q"):
                return .closeRequested
            case .escape where list.query.isEmpty:
                return .closeRequested
            case .char("J"):
                detailOffset += 1
                return nil
            case .char("K"):
                detailOffset = max(0, detailOffset - 1)
                return nil
            default:
                break
            }
        }
        let before = list.cursor
        let event = list.handle(key)
        if list.cursor != before { detailOffset = 0 }
        switch event {
        case .activated(let id)?:
            return entries[id]?.isEnabled == false ? .unavailable(id) : .accepted(id)
        case .toggled(let id)?:
            return .toggled(id)
        case .queryChanged?, nil:
            return nil
        }
    }

    /// Counted or absolute movement over the rows; horizontal steps fold.
    public mutating func apply(
        _ command: TerminalNavigationCommand
    ) {
        let before = list.cursor
        list.apply(command)
        if list.cursor != before { detailOffset = 0 }
    }

    public mutating func render(
        into frame: inout TerminalFrame,
        in region: TerminalRegion,
        theme: TerminalTheme = .standard,
        columns: Int = 82,
        rows requestedRows: Int = 22
    ) {
        let overlay = TerminalOverlay(
            placement: .centered(
                columns: min(max(1, columns), max(1, region.columns)),
                rows: min(max(1, requestedRows), max(1, region.rows))
            ),
            outerInsets: TerminalInsets(vertical: 1, horizontal: 2),
            contentInsets: TerminalInsets(vertical: 1, horizontal: 2)
        )
        let content = overlay.render(
            into: &frame,
            in: region,
            title: breadcrumb,
            zIndex: .overlay
        )
        guard !content.isEmpty else { return }

        let legends = legends
        let legend = list.cursor.flatMap { cursor in
            ([cursor] + list.ancestors(of: cursor).map(\.id).reversed()).compactMap { legends[$0] }.first
        }
        let layout = TerminalLayout.vertical(
            in: content,
            [.fixed(legend == nil ? 0 : 1), .flex(3), .fixed(1), .flex(2), .fixed(1)]
        )
        guard layout.count == 5 else { return }

        if let legend {
            frame.write([theme.caption.apply(legend)], in: layout[0], zIndex: .overlay)
        }
        list.render(into: &frame, in: layout[1], zIndex: .overlay)
        frame.write(
            theme.disabled.apply(String(repeating: "─", count: max(0, layout[2].columns))),
            in: layout[2],
            zIndex: .overlay
        )
        renderDetail(into: &frame, in: layout[3], theme: theme)
        frame.write(
            theme.caption.apply(list.statusLine ?? pendingText ?? instructions),
            in: layout[4],
            zIndex: .overlay
        )
    }
}

private extension TerminalSettingsTreeControl {
    static func item(
        _ entry: TerminalSettingsTreeEntry<ID>
    ) -> TerminalTreeListItem<ID> {
        TerminalTreeListItem(
            id: entry.id,
            title: entry.title,
            detail: entry.value ?? "",
            mark: mark(entry.accessory),
            style: entry.isEnabled ? .none : .dim,
            searchText: [entry.title, entry.value ?? "", entry.keywords].joined(separator: " ")
        )
    }

    static func mark(
        _ accessory: TerminalSettingsRowAccessory
    ) -> String {
        switch accessory {
        case .none, .disclosure: ""
        case .radio(let selected): selected ? "●" : "○"
        case .checkbox(let selected): selected ? "[x]" : "[ ]"
        case .indicators(let first, let second): "[\(first ? "●" : "○") \(second ? "●" : "○")]"
        }
    }

    func renderDetail(
        into frame: inout TerminalFrame,
        in region: TerminalRegion,
        theme: TerminalTheme
    ) {
        guard region.rows > 0, let entry = currentEntry else { return }
        let detail = entry.detail ?? TerminalSettingsDetail(title: entry.title, body: entry.value)
        let lines = TerminalBlock(
            title: detail.title ?? entry.title,
            fields: detail.fields,
            body: detail.body,
            theme: theme,
            layout: TerminalBlockLayout(
                fieldIndent: 0,
                labelWidth: .minimum(10),
                labelValueSpacing: 2,
                blankLinesAfter: 0
            )
        )
        .render(width: max(1, region.columns))
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map(String.init)
        frame.write(
            Array(lines.dropFirst(min(detailOffset, max(0, lines.count - region.rows))).prefix(region.rows)),
            in: region,
            zIndex: .overlay
        )
    }
}
