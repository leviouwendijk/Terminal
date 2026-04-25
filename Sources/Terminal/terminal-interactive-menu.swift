public struct TerminalInteractiveMenuConfiguration: Sendable, Codable, Hashable {
    public var listConfiguration: TerminalInteractiveListConfiguration

    public init(
        title: String,
        instructions: String = "",
        wrapMode: TerminalListNavigator.WrapMode = .wrap,
        useAlternateScreen: Bool = true,
        hideCursor: Bool = true,
        outputStream: TerminalStream = .standardError,
        presentation: TerminalInteractiveListPresentation = .fullscreen,
        completionPresentation: TerminalInteractiveListCompletionPresentation = .clear
    ) {
        self.listConfiguration = TerminalInteractiveListConfiguration(
            title: title,
            instructions: instructions,
            allowsMultipleSelection: false,
            wrapMode: wrapMode,
            useAlternateScreen: useAlternateScreen,
            hideCursor: hideCursor,
            outputStream: outputStream,
            presentation: presentation,
            completionPresentation: completionPresentation
        )
    }

    public init(
        listConfiguration: TerminalInteractiveListConfiguration
    ) {
        self.listConfiguration = TerminalInteractiveListConfiguration(
            title: listConfiguration.title,
            instructions: listConfiguration.instructions,
            allowsMultipleSelection: false,
            wrapMode: listConfiguration.wrapMode,
            useAlternateScreen: listConfiguration.useAlternateScreen,
            hideCursor: listConfiguration.hideCursor,
            outputStream: listConfiguration.outputStream,
            presentation: listConfiguration.presentation,
            completionPresentation: listConfiguration.completionPresentation
        )
    }

    public static func inline(
        title: String,
        instructions: String = "",
        wrapMode: TerminalListNavigator.WrapMode = .wrap,
        outputStream: TerminalStream = .standardError,
        completionPresentation: TerminalInteractiveListCompletionPresentation = .leaveSummary
    ) -> TerminalInteractiveMenuConfiguration {
        TerminalInteractiveMenuConfiguration(
            listConfiguration: .inline(
                title: title,
                instructions: instructions,
                allowsMultipleSelection: false,
                wrapMode: wrapMode,
                outputStream: outputStream,
                completionPresentation: completionPresentation
            )
        )
    }
}

public struct TerminalInteractiveMenuRow<Item: Sendable, ID: Hashable & Sendable>: Sendable {
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

public enum TerminalInteractiveMenuResult<Item: Sendable, ID: Hashable & Sendable>: Sendable {
    case picked(
        item: Item,
        id: ID
    )
    case cancelled

    public var wasPicked: Bool {
        switch self {
        case .picked:
            return true

        case .cancelled:
            return false
        }
    }

    public var item: Item? {
        switch self {
        case .picked(let item, _):
            return item

        case .cancelled:
            return nil
        }
    }

    public var id: ID? {
        switch self {
        case .picked(_, let id):
            return id

        case .cancelled:
            return nil
        }
    }
}

public struct TerminalInteractiveMenu<Item: Sendable, ID: Hashable & Sendable>: Sendable {
    public typealias IDProvider = @Sendable (Item) -> ID
    public typealias EnabledProvider = @Sendable (Item) -> Bool
    public typealias RowRenderer = @Sendable (TerminalInteractiveMenuRow<Item, ID>) -> String
    public typealias SummaryRenderer = @Sendable (TerminalInteractiveMenuResult<Item, ID>) -> String

    public var items: [Item]
    public var configuration: TerminalInteractiveMenuConfiguration

    private var idProvider: IDProvider
    private var enabledProvider: EnabledProvider
    private var rowRenderer: RowRenderer
    private var summaryRenderer: SummaryRenderer?

    public init(
        items: [Item],
        configuration: TerminalInteractiveMenuConfiguration,
        id: @escaping IDProvider,
        isEnabled: @escaping EnabledProvider = { _ in true },
        row: @escaping RowRenderer,
        summary: SummaryRenderer? = nil
    ) {
        self.items = items
        self.configuration = configuration
        self.idProvider = id
        self.enabledProvider = isEnabled
        self.rowRenderer = row
        self.summaryRenderer = summary
    }

    public func run() throws -> TerminalInteractiveMenuResult<Item, ID> {
        let summaryAdapter: TerminalInteractiveList<Item, ID>.SummaryRenderer?

        if let summaryRenderer {
            summaryAdapter = { result in
                summaryRenderer(
                    Self.menuResult(
                        from: result,
                        idProvider: idProvider
                    )
                )
            }
        } else {
            summaryAdapter = nil
        }

        let list = TerminalInteractiveList<Item, ID>(
            items: items,
            configuration: configuration.listConfiguration,
            id: idProvider,
            isEnabled: enabledProvider,
            row: { row in
                rowRenderer(
                    TerminalInteractiveMenuRow(
                        item: row.item,
                        id: row.id,
                        index: row.index,
                        isCurrent: row.isCurrent,
                        isEnabled: row.isEnabled
                    )
                )
            },
            summary: summaryAdapter
        )

        let result = try list.run()

        return Self.menuResult(
            from: result,
            idProvider: idProvider
        )
    }

    private static func menuResult(
        from result: TerminalInteractiveListResult<Item, ID>,
        idProvider: IDProvider
    ) -> TerminalInteractiveMenuResult<Item, ID> {
        switch result {
        case .accepted(let current, _, _):
            guard let current else {
                return .cancelled
            }

            return .picked(
                item: current,
                id: idProvider(current)
            )

        case .cancelled:
            return .cancelled
        }
    }
}
