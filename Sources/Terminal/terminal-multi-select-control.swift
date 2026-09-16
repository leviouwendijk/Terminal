public struct TerminalMultiSelectControlRow<
    Item: Sendable,
    ID: Hashable & Sendable
>:
    Sendable
{
    public var item: Item
    public var id: ID
    public var index: Int
    public var isCurrent: Bool
    public var isSelected: Bool
    public var isEnabled: Bool

    public init(
        item: Item,
        id: ID,
        index: Int,
        isCurrent: Bool,
        isSelected: Bool,
        isEnabled: Bool
    ) {
        self.item = item
        self.id = id
        self.index = index
        self.isCurrent = isCurrent
        self.isSelected = isSelected
        self.isEnabled = isEnabled
    }
}

public enum TerminalMultiSelectControlEvent<
    ID: Hashable & Sendable
>:
    Sendable,
    Hashable
{
    case currentChanged(ID)
    case selectionChanged([ID])
    case accepted([ID])
    case cancelRequested
}

public struct TerminalMultiSelectControl<
    Item: Sendable,
    ID: Hashable & Sendable
>:
    Sendable
{
    public typealias IDProvider = @Sendable (Item) -> ID
    public typealias EnabledProvider = @Sendable (Item) -> Bool
    public typealias RowRenderer = @Sendable (
        TerminalMultiSelectControlRow<Item, ID>
    ) -> String

    public private(set) var list: TerminalListControl<Item, ID>
    public private(set) var selection: TerminalSelectionSet<ID>

    private let idProvider: IDProvider
    private let enabledProvider: EnabledProvider

    public init(
        items: [Item],
        currentID: ID? = nil,
        selectedIDs: Set<ID> = [],
        wrapMode: TerminalListNavigator.WrapMode = .wrap,
        id: @escaping IDProvider,
        isEnabled: @escaping EnabledProvider = { _ in true }
    ) {
        self.idProvider = id
        self.enabledProvider = isEnabled
        self.list = TerminalListControl(
            items: items,
            currentID: currentID,
            wrapMode: wrapMode,
            id: id,
            isEnabled: isEnabled
        )
        self.selection = TerminalSelectionSet(
            selected: Set(
                selectedIDs.filter { selectedID in
                    items.contains { item in
                        id(item) == selectedID
                            && isEnabled(item)
                    }
                }
            )
        )
    }

    public var items: [Item] {
        list.items
    }

    public var currentItem: Item? {
        list.currentItem
    }

    public var currentID: ID? {
        list.currentID
    }

    public var selectedIDs: [ID] {
        items.compactMap { item in
            let id = idProvider(item)

            return selection.contains(id)
                ? id
                : nil
        }
    }

    public var selectedItems: [Item] {
        items.filter { item in
            selection.contains(
                idProvider(item)
            )
        }
    }

    public func rows() -> [
        TerminalMultiSelectControlRow<Item, ID>
    ] {
        list.rows().map { row in
            TerminalMultiSelectControlRow(
                item: row.item,
                id: row.id,
                index: row.index,
                isCurrent: row.isCurrent,
                isSelected: selection.contains(
                    row.id
                ),
                isEnabled: row.isEnabled
            )
        }
    }

    public mutating func updateItems(
        _ items: [Item],
        preservingCurrent: Bool = true
    ) {
        let selected = selection.selected

        list.updateItems(
            items,
            preservingCurrent: preservingCurrent
        )

        selection = TerminalSelectionSet(
            selected: Set(
                items.compactMap { item in
                    let id = idProvider(item)

                    guard selected.contains(id),
                          enabledProvider(item) else {
                        return nil
                    }

                    return id
                }
            )
        )
    }

    @discardableResult
    public mutating func select(
        id: ID
    ) -> Bool {
        guard items.contains(where: { item in
            idProvider(item) == id
                && enabledProvider(item)
        }) else {
            return false
        }

        let changed = !selection.contains(id)
        selection.select(id)
        return changed
    }

    @discardableResult
    public mutating func deselect(
        id: ID
    ) -> Bool {
        let changed = selection.contains(id)
        selection.deselect(id)
        return changed
    }

    public mutating func toggleCurrent()
        -> TerminalMultiSelectControlEvent<ID>?
    {
        guard let currentItem,
              enabledProvider(currentItem) else {
            return nil
        }

        let id = idProvider(currentItem)
        selection.toggle(id)

        return .selectionChanged(
            selectedIDs
        )
    }

    public mutating func handle(
        _ key: TerminalKey
    ) -> TerminalMultiSelectControlEvent<ID>? {
        switch key {
        case .space,
             .controlSpace:
            return toggleCurrent()

        default:
            break
        }

        guard let event = list.handle(key) else {
            return nil
        }

        switch event {
        case .currentChanged(let id):
            return .currentChanged(id)

        case .accepted:
            return .accepted(
                selectedIDs
            )

        case .cancelRequested:
            return .cancelRequested
        }
    }

    public func render(
        into frame: inout TerminalFrame,
        in region: TerminalRegion,
        row: RowRenderer
    ) {
        frame.write(
            rows().map(row),
            in: region
        )
    }
}
