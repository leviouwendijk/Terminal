public enum TerminalSettingsRowAccessory:
    Sendable,
    Hashable
{
    case none
    case disclosure
    case radio(selected: Bool)
    case checkbox(selected: Bool)
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

    private var list: TerminalListControl<
        TerminalSettingsRow<ID>,
        ID
    >

    public init(
        title: String,
        path: [String] = [],
        rows: [TerminalSettingsRow<ID>],
        currentID: ID? = nil,
        instructions: String = "j/k move  enter select  space toggle  q back"
    ) {
        self.title = title
        self.path = path
        self.rows = rows
        self.instructions = instructions
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
        instructions: String? = nil
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
        list.updateItems(
            rows,
            preservingCurrent: preservingCurrent
        )
    }

    @discardableResult
    public mutating func select(
        id: ID
    ) -> Bool {
        list.select(
            id: id
        )
    }

    public mutating func handle(
        _ key: TerminalKey
    ) -> TerminalSettingsMenuEvent<ID>? {
        switch key {
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
                columns: columns,
                rows: requestedRows
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

        let rows = list.rows()
        let currentIndex = list.currentIndex ?? 0
        let visibleCount = max(
            1,
            region.rows
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
            return
        }

        let rendered = rows[start..<end].map { row in
            renderRow(
                row,
                width: region.columns,
                theme: theme
            )
        }

        frame.write(
            Array(rendered),
            in: region,
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
        let value = item.value ?? ""
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
            + style.apply(
                accessory + title
            )

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
                lines.prefix(
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
        }
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
