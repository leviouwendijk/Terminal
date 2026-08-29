public struct TerminalListControlRow<
    Item: Sendable,
    ID: Hashable & Sendable
>:
    Sendable
{
    public var item: Item
    public var id: ID
    public var index: Int
    public var isCurrent: Bool
    public var isEnabled: Bool

    public init(
        item: Item,
        id: ID,
        index: Int,
        isCurrent: Bool,
        isEnabled: Bool
    ) {
        self.item = item
        self.id = id
        self.index = index
        self.isCurrent = isCurrent
        self.isEnabled = isEnabled
    }
}

public enum TerminalListControlEvent<
    ID: Hashable & Sendable
>:
    Sendable,
    Hashable
{
    case currentChanged(ID)
    case accepted(ID)
    case cancelRequested
}

public struct TerminalListControl<
    Item: Sendable,
    ID: Hashable & Sendable
>:
    Sendable
{
    public typealias IDProvider =
        @Sendable (Item) -> ID
    public typealias EnabledProvider =
        @Sendable (Item) -> Bool
    public typealias RowRenderer =
        @Sendable (
            TerminalListControlRow<Item, ID>
        ) -> String

    public private(set) var items: [Item]
    public private(set) var navigator: TerminalListNavigator

    private let idProvider: IDProvider
    private let enabledProvider: EnabledProvider

    public init(
        items: [Item],
        currentID: ID? = nil,
        wrapMode: TerminalListNavigator.WrapMode = .wrap,
        id: @escaping IDProvider,
        isEnabled: @escaping EnabledProvider = { _ in true }
    ) {
        self.items = items
        self.idProvider = id
        self.enabledProvider = isEnabled

        let selectedIndex =
            currentID
                .flatMap { currentID in
                    items.firstIndex { item in
                        id(item) == currentID
                            && isEnabled(item)
                    }
                }
            ?? items.firstIndex(
                where: isEnabled
            )
            ?? 0

        self.navigator = TerminalListNavigator(
            count: items.count,
            selectedIndex: selectedIndex,
            wrapMode: wrapMode
        )
    }

    public var currentIndex: Int? {
        guard
            let index = navigator.selection,
            items.indices.contains(index),
            enabledProvider(items[index])
        else {
            return nil
        }

        return index
    }

    public var currentItem: Item? {
        currentIndex.map {
            items[$0]
        }
    }

    public var currentID: ID? {
        currentItem.map(
            idProvider
        )
    }

    public func rows() -> [
        TerminalListControlRow<Item, ID>
    ] {
        items.indices.map { index in
            let item = items[index]

            return TerminalListControlRow(
                item: item,
                id: idProvider(item),
                index: index,
                isCurrent:
                    currentIndex == index,
                isEnabled:
                    enabledProvider(item)
            )
        }
    }

    public mutating func updateItems(
        _ items: [Item],
        preservingCurrent: Bool = true
    ) {
        let previousID =
            preservingCurrent
            ? currentID
            : nil

        self.items = items
        navigator.updateCount(
            items.count
        )

        if let previousID,
           let index = items.firstIndex(
               where: { item in
                   idProvider(item) == previousID
                       && enabledProvider(item)
               }
           ) {
            navigator.select(
                index
            )
            return
        }

        if let index = items.firstIndex(
            where: enabledProvider
        ) {
            navigator.select(
                index
            )
        }
    }

    @discardableResult
    public mutating func select(
        id: ID
    ) -> Bool {
        guard let index = items.firstIndex(
            where: { item in
                idProvider(item) == id
                    && enabledProvider(item)
            }
        ) else {
            return false
        }

        let changed = currentIndex != index
        navigator.select(
            index
        )
        return changed
    }

    public mutating func handle(
        _ key: TerminalKey
    ) -> TerminalListControlEvent<ID>? {
        if key.isVerticalPrevious {
            return move(
                direction: -1
            )
        }

        if key.isVerticalNext {
            return move(
                direction: 1
            )
        }

        switch key {
        case .home:
            return selectBoundary(
                first: true
            )

        case .end:
            return selectBoundary(
                first: false
            )

        case .enter:
            guard let currentID else {
                return nil
            }

            return .accepted(
                currentID
            )

        case .escape:
            return .cancelRequested

        default:
            return nil
        }
    }

    public func render(
        into frame: inout TerminalFrame,
        in region: TerminalRegion,
        row: RowRenderer
    ) {
        frame.write(
            rows().map(
                row
            ),
            in: region
        )
    }

    private mutating func move(
        direction: Int
    ) -> TerminalListControlEvent<ID>? {
        guard !items.isEmpty,
              items.contains(where: enabledProvider) else {
            return nil
        }

        let previousID = currentID

        for _ in items.indices {
            if direction < 0 {
                navigator.moveUp()
            } else {
                navigator.moveDown()
            }

            if currentIndex != nil {
                break
            }
        }

        guard let currentID,
              currentID != previousID else {
            return nil
        }

        return .currentChanged(
            currentID
        )
    }

    private mutating func selectBoundary(
        first: Bool
    ) -> TerminalListControlEvent<ID>? {
        let indices: AnySequence<Int>

        if first {
            indices = AnySequence(
                items.indices
            )
        } else {
            indices = AnySequence(
                items.indices.reversed()
            )
        }

        guard let index = indices.first(
            where: { index in
                enabledProvider(
                    items[index]
                )
            }
        ) else {
            return nil
        }

        let previousID = currentID
        navigator.select(
            index
        )

        guard let currentID,
              currentID != previousID else {
            return nil
        }

        return .currentChanged(
            currentID
        )
    }
}
