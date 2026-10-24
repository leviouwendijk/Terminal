public enum TerminalSettingsRowAccessory:
    Sendable,
    Hashable
{
    case none
    case disclosure
    case radio(selected: Bool)
    case checkbox(selected: Bool)
    /// Two independent, generic on/off markers. The caller supplies their meaning.
    case indicators(first: Bool, second: Bool)
}

public struct TerminalSettingsDetail:
    Sendable,
    Hashable
{
    public var title: String?
    public var fields: [TerminalField]
    public var body: String?

    public init(
        title: String? = nil,
        fields: [TerminalField] = [],
        body: String? = nil
    ) {
        self.title = title
        self.fields = fields
        self.body = body
    }
}

public struct TerminalSettingsRow<
    ID: Hashable & Sendable
>:
    Sendable,
    Hashable
{
    public var id: ID
    public var title: String
    public var value: String?
    public var caption: String?
    public var isEnabled: Bool
    public var accessory: TerminalSettingsRowAccessory
    public var detail: TerminalSettingsDetail?

    public init(
        id: ID,
        title: String,
        value: String? = nil,
        caption: String? = nil,
        isEnabled: Bool = true,
        accessory: TerminalSettingsRowAccessory = .none,
        detail: TerminalSettingsDetail? = nil
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.caption = caption
        self.isEnabled = isEnabled
        self.accessory = accessory
        self.detail = detail
    }
}

public enum TerminalSettingsMenuEvent<
    ID: Hashable & Sendable
>:
    Sendable,
    Hashable
{
    case currentChanged(ID)
    case accepted(ID)
    case toggled(ID)
    case unavailable(ID)
    case cancelRequested
}

public struct TerminalSettingsMenuControl<
    ID: Hashable & Sendable
>:
    Sendable
{
    public private(set) var title: String
    public private(set) var path: [String]
    public private(set) var rows: [TerminalSettingsRow<ID>]
    public var instructions: String
    public var rowLegend: String?

    private var list: TerminalListControl<
        TerminalSettingsRow<ID>,
        ID
    >

    // View-local inspection position; never part of the selected setting.
    private var detailOffset: Int = 0

    public init(
        title: String,
        path: [String] = [],
        rows: [TerminalSettingsRow<ID>],
        currentID: ID? = nil,
        instructions: String = "j/k move  enter select  space toggle  q back",
        rowLegend: String? = nil
    ) {
        self.title = title
        self.path = path
        self.rows = rows
        self.instructions = instructions
        self.rowLegend = rowLegend
        self.list = TerminalListControl(
            items: rows,
            currentID: currentID,
            id: { row in
                row.id
            }
        )
    }

    public var currentID: ID? {
        list.currentID
    }

    public var currentRow: TerminalSettingsRow<ID>? {
        list.currentItem
    }

    public var breadcrumb: String {
        ([title] + path).joined(
            separator: " / "
        )
    }

    public mutating func update(
        title: String? = nil,
        path: [String]? = nil,
        rows: [TerminalSettingsRow<ID>],
        preservingCurrent: Bool = true,
        instructions: String? = nil,
        rowLegend: String? = nil
    ) {
        if let title {
            self.title = title
        }

        if let path {
            self.path = path
        }

        if let instructions {
            self.instructions = instructions
        }

        self.rows = rows
        self.rowLegend = rowLegend
        detailOffset = 0
        list.updateItems(
            rows,
            preservingCurrent: preservingCurrent
        )
    }

    @discardableResult
    public mutating func select(
        id: ID
    ) -> Bool {
        let changed = list.select(
            id: id
        )
        if changed { detailOffset = 0 }
        return changed
    }

    public mutating func handle(
        _ key: TerminalKey
    ) -> TerminalSettingsMenuEvent<ID>? {
        switch key {
        case .char("J"):
            detailOffset += 1
            return nil

        case .char("K"):
            detailOffset = max(0, detailOffset - 1)
            return nil

        case .char("q"),
             .char("h"),
             .left,
             .escape:
            return .cancelRequested

        case .space:
            guard let row = currentRow else {
                return nil
            }

            guard row.isEnabled else {
                return .unavailable(
                    row.id
                )
            }

            return .toggled(
                row.id
            )

        case .char("l"):
            return acceptCurrent()

        default:
            break
        }

        guard let event = list.handle(
            key
        ) else {
            return nil
        }

        switch event {
        case .currentChanged(let id):
            detailOffset = 0
            return .currentChanged(
                id
            )

        case .accepted:
            return acceptCurrent()

        case .cancelRequested:
            return .cancelRequested
        }
    }

    public func render(
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
            outerInsets: TerminalInsets(
                vertical: 1,
                horizontal: 2
            ),
            contentInsets: TerminalInsets(
                vertical: 1,
                horizontal: 2
            )
        )
        let content = overlay.render(
            into: &frame,
            in: region,
            title: breadcrumb,
            zIndex: .overlay
        )

        guard !content.isEmpty else {
            return
        }

        let layout = TerminalLayout.vertical(
            in: content,
            [
                .flex(3),
                .fixed(1),
                .flex(2),
                .fixed(1),
            ]
        )

        guard layout.count == 4 else {
            return
        }

        renderRows(
            into: &frame,
            in: layout[0],
            theme: theme
        )

        frame.write(
            theme.disabled.apply(
                String(
                    repeating: "─",
                    count: max(
                        0,
                        layout[1].columns
                    )
                )
            ),
            in: layout[1],
            zIndex: .overlay
        )

        renderDetail(
            into: &frame,
            in: layout[2],
            theme: theme
        )

        frame.write(
            theme.caption.apply(
                instructions
            ),
            in: layout[3],
            zIndex: .overlay
        )
    }
}

private extension TerminalSettingsMenuControl {
    mutating func acceptCurrent()
        -> TerminalSettingsMenuEvent<ID>?
    {
        guard let row = currentRow else {
            return nil
        }

        guard row.isEnabled else {
            return .unavailable(
                row.id
            )
        }

        return .accepted(
            row.id
        )
    }

    func renderRows(
        into frame: inout TerminalFrame,
        in region: TerminalRegion,
        theme: TerminalTheme
    ) {
        guard region.rows > 0 else {
            return
        }

        var listRegion = region
        if let rowLegend, !rowLegend.isEmpty {
            frame.write(
                theme.caption.apply(
                    TerminalDisplay.clipped(rowLegend, columns: region.columns)
                ),
                in: TerminalRegion(
                    top: region.top,
                    leading: region.leading,
                    rows: 1,
                    columns: region.columns
                ),
                zIndex: .overlay
            )
            listRegion = TerminalRegion(
                top: region.top + 1,
                leading: region.leading,
                rows: max(0, region.rows - 1),
                columns: region.columns
            )
        }

        guard listRegion.rows > 0 else { return }

        let rows = list.rows()
        let currentIndex = list.currentIndex ?? 0
        let visibleCount = max(
            1,
            listRegion.rows
        )
        let maximumStart = max(
            0,
            rows.count - visibleCount
        )
        let proposedStart = max(
            0,
            currentIndex - visibleCount / 2
        )
        let start = min(
            maximumStart,
            proposedStart
        )
        let end = min(
            rows.count,
            start + visibleCount
        )

        guard start < end else {
            frame.write(
                theme.disabled.apply("No entries"),
                in: listRegion,
                zIndex: .overlay
            )
            return
        }

        let rendered = rows[start..<end].map { row in
            renderRow(
                row,
                width: listRegion.columns,
                theme: theme
            )
        }

        frame.write(
            Array(rendered),
            in: listRegion,
            zIndex: .overlay
        )
    }

    func renderRow(
        _ row: TerminalListControlRow<
            TerminalSettingsRow<ID>,
            ID
        >,
        width: Int,
        theme: TerminalTheme
    ) -> String {
        let item = row.item
        let cursor = row.isCurrent
            ? "> "
            : "  "
        let accessory = accessoryPrefix(
            item.accessory
        )
        let disclosure = disclosureSuffix(
            item.accessory
        )
        let rawValue = item.value ?? ""
        let value = TerminalDisplay.width(of: rawValue) + 14 <= width
            ? rawValue : ""
        let fixedWidth = TerminalDisplay.width(
            of: cursor + accessory + disclosure
        )
        let valueWidth = value.isEmpty
            ? 0
            : TerminalDisplay.width(
                of: value
            ) + 2
        let titleWidth = max(
            1,
            width - fixedWidth - valueWidth
        )
        let title = fitted(
            item.title,
            columns: titleWidth
        )
        let style: TerminalStyle

        if !item.isEnabled {
            style = theme.disabled
        } else if row.isCurrent {
            style = theme.cursor
        } else {
            style = theme.value
        }

        var rendered = cursor
            + styledAccessory(item.accessory, style: style, theme: theme)
            + style.apply(title)

        if !value.isEmpty {
            rendered += "  "
                + style.apply(
                    value
                )
        }

        if !disclosure.isEmpty {
            rendered += style.apply(
                disclosure
            )
        }

        return TerminalDisplay.clipped(
            rendered,
            columns: max(
                1,
                width
            )
        )
    }

    func renderDetail(
        into frame: inout TerminalFrame,
        in region: TerminalRegion,
        theme: TerminalTheme
    ) {
        guard region.rows > 0,
              let row = currentRow else {
            return
        }

        let detail = row.detail
            ?? TerminalSettingsDetail(
                title: row.title,
                body: row.caption
            )

        let block = TerminalBlock(
            title: detail.title ?? row.title,
            fields: detail.fields,
            body: detail.body,
            theme: theme,
            layout: TerminalBlockLayout(
                fieldIndent: 0,
                labelWidth: .minimum(10),
                labelValueSpacing: 2,
                blankLinesAfter: 0
            )
        ).render(
            width: max(
                1,
                region.columns
            )
        )

        let lines = block
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .map(String.init)

        frame.write(
            Array(
                lines.dropFirst(
                    min(detailOffset, max(0, lines.count - region.rows))
                ).prefix(
                    region.rows
                )
            ),
            in: region,
            zIndex: .overlay
        )
    }

    func accessoryPrefix(
        _ accessory: TerminalSettingsRowAccessory
    ) -> String {
        switch accessory {
        case .none,
             .disclosure:
            return ""

        case .radio(let selected):
            return selected
                ? "● "
                : "○ "

        case .checkbox(let selected):
            return selected
                ? "[x] "
                : "[ ] "

        case .indicators(let first, let second):
            return "[\(first ? "●" : "○") \(second ? "●" : "○")] "
        }
    }

    func styledAccessory(
        _ accessory: TerminalSettingsRowAccessory,
        style: TerminalStyle,
        theme: TerminalTheme
    ) -> String {
        guard case .indicators(let first, let second) = accessory else {
            return style.apply(accessoryPrefix(accessory))
        }

        return theme.disabled.apply("[")
            + (first ? theme.success : theme.disabled).apply(first ? "●" : "○")
            + theme.disabled.apply(" ")
            + (second ? theme.success : theme.disabled).apply(second ? "●" : "○")
            + theme.disabled.apply("] ")
    }

    func disclosureSuffix(
        _ accessory: TerminalSettingsRowAccessory
    ) -> String {
        if case .disclosure = accessory {
            return " >"
        }

        return ""
    }

    func fitted(
        _ text: String,
        columns: Int
    ) -> String {
        let clipped = TerminalDisplay.clipped(
            text,
            columns: columns
        )
        let padding = max(
            0,
            columns - TerminalDisplay.width(
                of: clipped
            )
        )

        return clipped
            + String(
                repeating: " ",
                count: padding
            )
    }
}
