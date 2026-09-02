public enum TerminalTimelineItemState:
    Sendable,
    Hashable
{
    case pending
    case active
    case completed
    case failed
    case skipped
}

public struct TerminalTimelineItem<
    ID: Hashable & Sendable
>:
    Sendable,
    Hashable
{
    public var id: ID
    public var title: String
    public var detail: String?
    public var state: TerminalTimelineItemState
    public var groups: [String]

    public init(
        id: ID,
        title: String,
        detail: String? = nil,
        state: TerminalTimelineItemState,
        groups: [String] = []
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.state = state
        self.groups = groups
    }
}

public struct TerminalTimelineStyle:
    Sendable,
    Hashable
{
    public var selectionMarker: String
    public var completedMarker: String
    public var activeMarker: String
    public var pendingMarker: String
    public var failedMarker: String
    public var skippedMarker: String
    public var connector: String
    public var groupBranch: String
    public var groupIndent: Int

    public var selection: TerminalStyle
    public var completed: TerminalStyle
    public var active: TerminalStyle
    public var pending: TerminalStyle
    public var failed: TerminalStyle
    public var skipped: TerminalStyle
    public var detail: TerminalStyle
    public var connectorStyle: TerminalStyle
    public var group: TerminalStyle

    public init(
        selectionMarker: String = ">",
        completedMarker: String = "✓",
        activeMarker: String = "◉",
        pendingMarker: String = "○",
        failedMarker: String = "×",
        skippedMarker: String = "─",
        connector: String = "│",
        groupBranch: String = "└─",
        groupIndent: Int = 3,
        selection: TerminalStyle = .bold,
        completed: TerminalStyle = TerminalStyle(
            .green
        ),
        active: TerminalStyle = .bold,
        pending: TerminalStyle = .dim,
        failed: TerminalStyle = TerminalStyle(
            .bold,
            .red
        ),
        skipped: TerminalStyle = .dim,
        detail: TerminalStyle = .dim,
        connectorStyle: TerminalStyle = .dim,
        group: TerminalStyle = .dim
    ) {
        self.selectionMarker = selectionMarker
        self.completedMarker = completedMarker
        self.activeMarker = activeMarker
        self.pendingMarker = pendingMarker
        self.failedMarker = failedMarker
        self.skippedMarker = skippedMarker
        self.connector = connector
        self.groupBranch = groupBranch
        self.groupIndent = max(
            0,
            groupIndent
        )
        self.selection = selection
        self.completed = completed
        self.active = active
        self.pending = pending
        self.failed = failed
        self.skipped = skipped
        self.detail = detail
        self.connectorStyle = connectorStyle
        self.group = group
    }

    public static let standard =
        TerminalTimelineStyle()

    public static let plain =
        TerminalTimelineStyle(
            selection: .none,
            completed: .none,
            active: .none,
            pending: .none,
            failed: .none,
            skipped: .none,
            detail: .none,
            connectorStyle: .none,
            group: .none
        )
}

public struct TerminalTimelineLayout<
    ID: Hashable & Sendable
>:
    Sendable
{
    public var lines: [String]
    public var itemRows: [ID: Range<Int>]

    public init(
        lines: [String],
        itemRows: [ID: Range<Int>]
    ) {
        self.lines = lines
        self.itemRows = itemRows
    }
}

public struct TerminalTimeline<
    ID: Hashable & Sendable
>:
    Sendable,
    Hashable
{
    public var items: [TerminalTimelineItem<ID>]
    public var style: TerminalTimelineStyle

    public init(
        items: [TerminalTimelineItem<ID>],
        style: TerminalTimelineStyle = .standard
    ) {
        self.items = items
        self.style = style
    }

    public func layout(
        width: Int,
        selectedID: ID? = nil
    ) -> TerminalTimelineLayout<ID> {
        let width = max(
            0,
            width
        )
        var lines: [String] = []
        var itemRows: [ID: Range<Int>] = [:]
        var previousGroups: [String] = []

        for (
            index,
            item
        ) in items.enumerated() {
            let sharedDepth = commonGroupDepth(
                previousGroups,
                item.groups
            )

            if item.groups.count > sharedDepth {
                for depth in sharedDepth..<item.groups.count {
                    append(
                        groupIndentation(
                            depth: depth
                        )
                            + "  "
                            + style.group.apply(
                                style.groupBranch
                                    + " "
                                    + item.groups[depth]
                            ),
                        width: width,
                        to: &lines
                    )
                }
            }

            let indentation = groupIndentation(
                depth: item.groups.count
            )
            let textWidth = max(
                1,
                width
                    - TerminalDisplay.width(
                        of: indentation
                    )
                    - 4
            )
            let start = lines.count
            let selected = item.id == selectedID
            let itemStyle = stateStyle(
                for: item.state
            )
            let titleStyle = selected
                ? TerminalStyle(
                    codes:
                        style.selection.codes
                        + itemStyle.codes
                )
                : itemStyle
            let marker = TerminalDisplay.fitted(
                marker(
                    for: item.state
                ),
                columns: 1
            )
            let selection = selected
                ? style.selection.apply(
                    TerminalDisplay.fitted(
                        style.selectionMarker,
                        columns: 1
                    )
                )
                : " "
            let connector = style.connectorStyle.apply(
                TerminalDisplay.fitted(
                    style.connector,
                    columns: 1
                )
            )
            var titleLines = TerminalTextWrap.lines(
                item.title,
                width: textWidth
            )

            if titleLines.isEmpty {
                titleLines = [
                    "",
                ]
            }

            if let first = titleLines.first {
                append(
                    indentation
                        + selection
                        + " "
                        + itemStyle.apply(
                            marker
                        )
                        + " "
                        + titleStyle.apply(
                            first
                        ),
                    width: width,
                    to: &lines
                )
            }

            for line in titleLines.dropFirst() {
                append(
                    indentation
                        + "  "
                        + connector
                        + " "
                        + titleStyle.apply(
                            line
                        ),
                    width: width,
                    to: &lines
                )
            }

            if let detail = item.detail,
               !detail.isEmpty {
                for line in TerminalTextWrap.lines(
                    detail,
                    width: textWidth
                ) {
                    append(
                        indentation
                            + "  "
                            + connector
                            + " "
                            + style.detail.apply(
                                line
                            ),
                        width: width,
                        to: &lines
                    )
                }
            }

            itemRows[item.id] =
                start..<lines.count

            if index < items.count - 1 {
                let connectorDepth = commonGroupDepth(
                    item.groups,
                    items[index + 1].groups
                )

                append(
                    groupIndentation(
                        depth: connectorDepth
                    )
                        + "  "
                        + connector,
                    width: width,
                    to: &lines
                )
            }

            previousGroups = item.groups
        }

        return TerminalTimelineLayout(
            lines: lines,
            itemRows: itemRows
        )
    }

    public func render(
        width: Int,
        selectedID: ID? = nil
    ) -> String {
        layout(
            width: width,
            selectedID: selectedID
        ).lines.joined(
            separator: "\n"
        )
    }

    public func render(
        into frame: inout TerminalFrame,
        in region: TerminalRegion,
        selectedID: ID? = nil
    ) {
        frame.write(
            layout(
                width: region.columns,
                selectedID: selectedID
            ).lines,
            in: region
        )
    }

    private func marker(
        for state: TerminalTimelineItemState
    ) -> String {
        switch state {
        case .pending:
            return style.pendingMarker

        case .active:
            return style.activeMarker

        case .completed:
            return style.completedMarker

        case .failed:
            return style.failedMarker

        case .skipped:
            return style.skippedMarker
        }
    }

    private func stateStyle(
        for state: TerminalTimelineItemState
    ) -> TerminalStyle {
        switch state {
        case .pending:
            return style.pending

        case .active:
            return style.active

        case .completed:
            return style.completed

        case .failed:
            return style.failed

        case .skipped:
            return style.skipped
        }
    }

    private func commonGroupDepth(
        _ lhs: [String],
        _ rhs: [String]
    ) -> Int {
        var depth = 0

        while depth < lhs.count,
              depth < rhs.count,
              lhs[depth] == rhs[depth]
        {
            depth += 1
        }

        return depth
    }

    private func groupIndentation(
        depth: Int
    ) -> String {
        String(
            repeating: " ",
            count: max(
                0,
                depth
            ) * style.groupIndent
        )
    }

    private func append(
        _ line: String,
        width: Int,
        to lines: inout [String]
    ) {
        lines.append(
            TerminalDisplay.clipped(
                line,
                columns: width
            )
        )
    }
}
