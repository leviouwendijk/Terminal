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

    public init(
        id: ID,
        title: String,
        detail: String? = nil,
        state: TerminalTimelineItemState
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.state = state
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

    public var selection: TerminalStyle
    public var completed: TerminalStyle
    public var active: TerminalStyle
    public var pending: TerminalStyle
    public var failed: TerminalStyle
    public var skipped: TerminalStyle
    public var detail: TerminalStyle
    public var connectorStyle: TerminalStyle

    public init(
        selectionMarker: String = ">",
        completedMarker: String = "●",
        activeMarker: String = "◉",
        pendingMarker: String = "○",
        failedMarker: String = "×",
        skippedMarker: String = "─",
        connector: String = "│",
        selection: TerminalStyle = .bold,
        completed: TerminalStyle = .none,
        active: TerminalStyle = .bold,
        pending: TerminalStyle = .dim,
        failed: TerminalStyle = TerminalStyle(
            .bold,
            .red
        ),
        skipped: TerminalStyle = .dim,
        detail: TerminalStyle = .dim,
        connectorStyle: TerminalStyle = .dim
    ) {
        self.selectionMarker = selectionMarker
        self.completedMarker = completedMarker
        self.activeMarker = activeMarker
        self.pendingMarker = pendingMarker
        self.failedMarker = failedMarker
        self.skippedMarker = skippedMarker
        self.connector = connector
        self.selection = selection
        self.completed = completed
        self.active = active
        self.pending = pending
        self.failed = failed
        self.skipped = skipped
        self.detail = detail
        self.connectorStyle = connectorStyle
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
            connectorStyle: .none
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
        let textWidth = max(
            1,
            width - 4
        )
        var lines: [String] = []
        var itemRows: [ID: Range<Int>] = [:]

        for (
            index,
            item
        ) in items.enumerated() {
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
                    selection
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
                    "  "
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
                        "  "
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
                append(
                    "  " + connector,
                    width: width,
                    to: &lines
                )
            }
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
