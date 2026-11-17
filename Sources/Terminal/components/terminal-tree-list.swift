import Primitives

/// One entry of a `TerminalTreeList`; a branch when its node has children.
public struct TerminalTreeListItem<ID: Hashable & Sendable>: Sendable, Hashable {
    public var id: ID
    public var title: String
    /// Dim text after the title.
    public var detail: String
    /// A leading mark such as `●`, drawn before the title.
    public var mark: String
    public var style: TerminalStyle
    /// What a query matches against.
    public var searchText: String

    public init(
        id: ID,
        title: String,
        detail: String = "",
        mark: String = "",
        style: TerminalStyle = .none,
        searchText: String? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.mark = mark
        self.style = style
        self.searchText = searchText ?? [title, detail].joined(separator: " ")
    }
}

/// A netrw-like tree listing: indented rows, collapsible branches, and a
/// `/` filter that keeps matches with their ancestors and ranks siblings.
/// A value the caller owns: update it with a new tree, feed it keys, and
/// render it into a region. Matching is supplied by the caller, so ranking
/// libraries stay outside Terminal.
public struct TerminalTreeList<ID: Hashable & Sendable>: Sendable {
    /// Scores each candidate for a query; absent means no match, higher
    /// ranks first.
    public typealias Matcher = @Sendable (
        _ query: String,
        _ candidates: [(id: ID, text: String)]
    ) -> [ID: Int]

    public enum Event: Sendable, Equatable {
        /// Enter on a leaf.
        case activated(ID)
        /// Space on a leaf, e.g. a second switch beside Enter's.
        case toggled(ID)
        case queryChanged(String)
    }

    public struct Row: Sendable {
        public let item: TerminalTreeListItem<ID>
        public let depth: Int
        public let isBranch: Bool
        public let isExpanded: Bool
    }

    public private(set) var tree: Tree<TerminalTreeListItem<ID>>
    public private(set) var cursor: ID?
    public private(set) var collapsed: Set<ID>
    public private(set) var query: String = ""
    public private(set) var isEditingQuery = false
    public private(set) var rows: [Row] = []
    private var scroll = 0
    private let matcher: Matcher

    public init(
        tree: Tree<TerminalTreeListItem<ID>> = .init(),
        collapsed: Set<ID> = [],
        matcher: @escaping Matcher = TerminalTreeList.subsequenceMatcher
    ) {
        self.tree = tree
        self.collapsed = collapsed
        self.matcher = matcher
        rebuild()
    }

    /// Replaces the tree, keeping the cursor on the same item when it is
    /// still shown.
    public mutating func update(
        _ tree: Tree<TerminalTreeListItem<ID>>
    ) {
        self.tree = tree
        rebuild()
    }

    public var currentItem: TerminalTreeListItem<ID>? {
        rows.first { $0.item.id == cursor }?.item
    }

    /// While a query is typed every key belongs to the list.
    public var capturesInput: Bool {
        isEditingQuery
    }

    /// `/query` while typing, or the active filter and its match count.
    public var statusLine: String? {
        if isEditingQuery {
            return "/" + query + "▏"
        }
        guard !query.isEmpty else {
            return nil
        }
        let leaves = rows.filter { !$0.isBranch }.count
        return "/\(query)  ·  \(leaves) \(leaves == 1 ? "match" : "matches")  ·  Esc clears"
    }

    /// The items above `id`, outermost first.
    public func ancestors(
        of id: ID
    ) -> [TerminalTreeListItem<ID>] {
        var nodes = tree.roots
        var result: [TerminalTreeListItem<ID>] = []
        for ancestor in Self.path(to: id, in: tree.roots) ?? [] {
            guard let node = nodes.first(where: { $0.value.id == ancestor }) else { break }
            result.append(node.value)
            nodes = node.children
        }
        return result
    }

    /// Selects an item, expanding its ancestors.
    public mutating func select(
        _ id: ID
    ) {
        if let path = Self.path(to: id, in: tree.roots) {
            collapsed.subtract(path)
        }
        rebuild()
        if rows.contains(where: { $0.item.id == id }) {
            cursor = id
        }
    }

    /// Sets the filter without typing, e.g. from a command line.
    public mutating func filter(
        _ query: String
    ) {
        self.query = query
        isEditingQuery = false
        rebuild(resetCursor: true)
    }

    public mutating func handle(
        _ key: TerminalKey
    ) -> Event? {
        if isEditingQuery {
            switch key {
            case .enter:
                isEditingQuery = false
                return nil
            case .escape:
                isEditingQuery = false
                query = ""
            case .backspace:
                if query.isEmpty {
                    isEditingQuery = false
                    return nil
                }
                query.removeLast()
            case .space:
                query.append(" ")
            case .char(let character):
                query.append(character)
            default:
                return nil
            }
            rebuild(resetCursor: true)
            return .queryChanged(query)
        }

        guard let index = rows.firstIndex(where: { $0.item.id == cursor }) ?? rows.indices.first else {
            if key == .char("/") {
                isEditingQuery = true
            }
            return nil
        }
        let row = rows[index]

        switch key {
        case .char("j"), .down:
            cursor = rows[min(rows.count - 1, index + 1)].item.id
        case .char("k"), .up:
            cursor = rows[max(0, index - 1)].item.id
        case .char("g"), .home:
            cursor = rows.first?.item.id
        case .char("G"), .end:
            cursor = rows.last?.item.id
        case .char("h"), .left:
            if row.isBranch, row.isExpanded, query.isEmpty {
                collapsed.insert(row.item.id)
                rebuild()
            } else if let parent = rows[..<index].last(where: { $0.depth < row.depth }) {
                cursor = parent.item.id
            }
        case .char("l"), .right:
            if row.isBranch, !row.isExpanded {
                collapsed.remove(row.item.id)
                rebuild()
            } else if row.isBranch, index + 1 < rows.count {
                cursor = rows[index + 1].item.id
            }
        case .enter, .space:
            if row.isBranch {
                if row.isExpanded, query.isEmpty {
                    collapsed.insert(row.item.id)
                } else {
                    collapsed.remove(row.item.id)
                }
                rebuild()
            } else {
                return key == .enter ? .activated(row.item.id) : .toggled(row.item.id)
            }
        case .char("/"):
            isEditingQuery = true
            return nil
        case .escape where !query.isEmpty:
            query = ""
            rebuild(resetCursor: true)
            return .queryChanged(query)
        default:
            return nil
        }
        return nil
    }

    /// Indented rows in `region`, scrolled to keep the cursor visible.
    public mutating func render(
        into frame: inout TerminalFrame,
        in region: TerminalRegion,
        zIndex: TerminalZIndex = .base
    ) {
        guard region.rows > 0, region.columns > 0 else {
            return
        }
        let index = rows.firstIndex { $0.item.id == cursor } ?? 0
        if index < scroll {
            scroll = index
        } else if index >= scroll + region.rows {
            scroll = index - region.rows + 1
        }
        scroll = max(0, min(scroll, max(0, rows.count - region.rows)))

        let lines = rows.dropFirst(scroll).prefix(region.rows).map { row -> String in
            let marker = row.isBranch ? (row.isExpanded ? "▾ " : "▸ ") : "  "
            let mark = row.item.mark.isEmpty ? "" : row.item.mark + " "
            let plain = String(repeating: "  ", count: row.depth) + marker + mark + row.item.title
            let detail = row.item.detail.isEmpty ? "" : "  " + row.item.detail
            if row.item.id == cursor {
                return TerminalStyle(.inverse).apply(
                    TerminalDisplay.fitted(plain + detail, columns: region.columns)
                )
            }
            let title = row.isBranch && row.item.style.isEmpty
                ? TerminalStyle.bold.apply(plain)
                : row.item.style.apply(plain)
            return TerminalDisplay.clipped(title + TerminalStyle.dim.apply(detail), columns: region.columns)
        }
        frame.write(Array(lines), in: region, zIndex: zIndex)
    }

    /// Case-insensitive subsequence match; contiguous and earlier matches
    /// rank higher.
    public static func subsequenceMatcher(
        _ query: String,
        _ candidates: [(id: ID, text: String)]
    ) -> [ID: Int] {
        let needle = query.lowercased().filter { !$0.isWhitespace }
        guard !needle.isEmpty else {
            return [:]
        }
        var scores: [ID: Int] = [:]
        for candidate in candidates {
            let haystack = candidate.text.lowercased()
            if let range = haystack.range(of: needle) {
                scores[candidate.id] = 1_000 - haystack.distance(from: haystack.startIndex, to: range.lowerBound)
                continue
            }
            var remaining = needle[...]
            for character in haystack where character == remaining.first {
                remaining = remaining.dropFirst()
                if remaining.isEmpty { break }
            }
            if remaining.isEmpty {
                scores[candidate.id] = 1
            }
        }
        return scores
    }
}

private extension TerminalTreeList {
    typealias Node = Tree<TerminalTreeListItem<ID>>.Node

    mutating func rebuild(
        resetCursor: Bool = false
    ) {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            rows = visible(tree.roots, depth: 0)
        } else {
            var candidates: [(id: ID, text: String)] = []
            Self.collect(tree.roots, into: &candidates)
            let scores = matcher(query, candidates)
            rows = matching(tree.roots, depth: 0, scores: scores).flatMap(\.rows)
        }
        if resetCursor || !rows.contains(where: { $0.item.id == cursor }) {
            cursor = (resetCursor ? rows.first { !$0.isBranch } : nil)?.item.id ?? rows.first?.item.id
        }
    }

    func visible(
        _ nodes: [Node],
        depth: Int
    ) -> [Row] {
        nodes.flatMap { node -> [Row] in
            let isBranch = !node.children.isEmpty
            let isExpanded = isBranch && !collapsed.contains(node.value.id)
            let row = Row(item: node.value, depth: depth, isBranch: isBranch, isExpanded: isExpanded)
            return [row] + (isExpanded ? visible(node.children, depth: depth + 1) : [])
        }
    }

    /// Matching subtrees with their best score; siblings rank by it.
    func matching(
        _ nodes: [Node],
        depth: Int,
        scores: [ID: Int]
    ) -> [(score: Int, rows: [Row])] {
        nodes.compactMap { node -> (score: Int, rows: [Row])? in
            let isBranch = !node.children.isEmpty
            if let own = scores[node.value.id], isBranch {
                // A matching branch keeps its whole subtree.
                let row = Row(item: node.value, depth: depth, isBranch: true, isExpanded: true)
                return (own, [row] + all(node.children, depth: depth + 1))
            }
            let children = matching(node.children, depth: depth + 1, scores: scores)
            let best = ([scores[node.value.id]] + children.map(\.score)).compactMap { $0 }.max()
            guard let best else {
                return nil
            }
            let row = Row(item: node.value, depth: depth, isBranch: isBranch, isExpanded: isBranch)
            return (best, [row] + children.flatMap(\.rows))
        }
        .enumerated()
        .sorted { $0.element.score != $1.element.score ? $0.element.score > $1.element.score : $0.offset < $1.offset }
        .map(\.element)
    }

    func all(
        _ nodes: [Node],
        depth: Int
    ) -> [Row] {
        nodes.flatMap { node -> [Row] in
            let isBranch = !node.children.isEmpty
            return [Row(item: node.value, depth: depth, isBranch: isBranch, isExpanded: isBranch)]
                + all(node.children, depth: depth + 1)
        }
    }

    static func collect(
        _ nodes: [Node],
        into candidates: inout [(id: ID, text: String)]
    ) {
        for node in nodes {
            candidates.append((node.value.id, node.value.searchText))
            collect(node.children, into: &candidates)
        }
    }

    static func path(
        to id: ID,
        in nodes: [Node]
    ) -> [ID]? {
        for node in nodes {
            if node.value.id == id {
                return []
            }
            if let below = path(to: id, in: node.children) {
                return [node.value.id] + below
            }
        }
        return nil
    }
}

extension TerminalTreeList {
    /// Moves the cursor over visible rows. Horizontal steps repeat the tree's
    /// collapse/parent and expand/child moves until nothing changes.
    @discardableResult
    public mutating func apply(
        _ command: TerminalNavigationCommand,
        pageRows: Int
    ) -> Event? {
        guard !isEditingQuery,
              !rows.isEmpty else {
            return nil
        }

        let index = rows.firstIndex { $0.item.id == cursor } ?? 0

        switch command {
        case .first:
            cursor = rows.first?.item.id

        case .last:
            cursor = rows.last?.item.id

        case .position(let position):
            cursor = rows[
                min(rows.count - 1, max(0, position))
            ].item.id

        case .horizontal(let steps):
            let key: TerminalKey = steps < 0 ? .left : .right
            var event: Event?
            for _ in 0..<abs(
                TerminalNavigationCommand.bounded(
                    steps,
                    to: rows.count
                )
            ) {
                let before = (cursor, rows.count)
                event = handle(key) ?? event
                if before == (cursor, rows.count) {
                    break
                }
            }
            return event

        case .vertical,
             .page,
             .halfPage:
            guard let steps = command.verticalSteps(
                pageRows: pageRows
            ) else {
                return nil
            }

            let bounded = TerminalNavigationCommand.bounded(
                steps,
                to: rows.count
            )
            cursor = rows[
                min(rows.count - 1, max(0, index + bounded))
            ].item.id
        }

        return nil
    }
}
