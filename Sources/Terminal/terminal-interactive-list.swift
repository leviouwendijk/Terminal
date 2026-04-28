public enum TerminalInteractiveListPresentation: String, Sendable, Codable, Hashable {
    case fullscreen
    case inline
}

public enum TerminalInteractiveListCompletionPresentation: String, Sendable, Codable, Hashable {
    case clear
    case leaveLastFrame
    case leaveSummary
}

public enum TerminalInteractiveCurrentRowStyle: String, Sendable, Codable, Hashable {
    case inverse
    case none
}

public struct TerminalInteractiveListConfiguration: Sendable, Codable, Hashable {
    public var title: String
    public var instructions: String
    public var allowsMultipleSelection: Bool
    public var wrapMode: TerminalListNavigator.WrapMode
    public var useAlternateScreen: Bool
    public var hideCursor: Bool
    public var outputStream: TerminalStream
    public var presentation: TerminalInteractiveListPresentation
    public var completionPresentation: TerminalInteractiveListCompletionPresentation
    public var currentRowStyle: TerminalInteractiveCurrentRowStyle

    public init(
        title: String,
        instructions: String = "",
        allowsMultipleSelection: Bool = true,
        wrapMode: TerminalListNavigator.WrapMode = .wrap,
        useAlternateScreen: Bool = true,
        hideCursor: Bool = true,
        outputStream: TerminalStream = .standardError,
        presentation: TerminalInteractiveListPresentation = .fullscreen,
        completionPresentation: TerminalInteractiveListCompletionPresentation = .clear,
        currentRowStyle: TerminalInteractiveCurrentRowStyle = .inverse
    ) {
        self.title = title
        self.instructions = instructions
        self.allowsMultipleSelection = allowsMultipleSelection
        self.wrapMode = wrapMode
        self.useAlternateScreen = useAlternateScreen
        self.hideCursor = hideCursor
        self.outputStream = outputStream
        self.presentation = presentation
        self.completionPresentation = completionPresentation
        self.currentRowStyle = currentRowStyle
    }

    public static func inline(
        title: String,
        instructions: String = "",
        allowsMultipleSelection: Bool = true,
        wrapMode: TerminalListNavigator.WrapMode = .wrap,
        outputStream: TerminalStream = .standardError,
        completionPresentation: TerminalInteractiveListCompletionPresentation = .leaveSummary,
        currentRowStyle: TerminalInteractiveCurrentRowStyle = .inverse
    ) -> TerminalInteractiveListConfiguration {
        TerminalInteractiveListConfiguration(
            title: title,
            instructions: instructions,
            allowsMultipleSelection: allowsMultipleSelection,
            wrapMode: wrapMode,
            useAlternateScreen: false,
            hideCursor: true,
            outputStream: outputStream,
            presentation: .inline,
            completionPresentation: completionPresentation,
            currentRowStyle: currentRowStyle
        )
    }
}

public struct TerminalInteractiveListRow<Item: Sendable, ID: Hashable & Sendable>: Sendable {
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

public enum TerminalInteractiveListResult<Item: Sendable, ID: Hashable & Sendable>: Sendable {
    case accepted(
        current: Item?,
        selected: [Item],
        selectedIDs: [ID]
    )
    case cancelled

    public var wasAccepted: Bool {
        switch self {
        case .accepted:
            return true

        case .cancelled:
            return false
        }
    }
}

public struct TerminalInteractiveList<Item: Sendable, ID: Hashable & Sendable>: Sendable {
    public typealias IDProvider = @Sendable (Item) -> ID
    public typealias EnabledProvider = @Sendable (Item) -> Bool
    public typealias RowRenderer = @Sendable (TerminalInteractiveListRow<Item, ID>) -> String
    public typealias SummaryRenderer = @Sendable (TerminalInteractiveListResult<Item, ID>) -> String

    public var items: [Item]
    public var configuration: TerminalInteractiveListConfiguration

    private var idProvider: IDProvider
    private var enabledProvider: EnabledProvider
    private var rowRenderer: RowRenderer
    private var summaryRenderer: SummaryRenderer?

    public init(
        items: [Item],
        configuration: TerminalInteractiveListConfiguration,
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

    public func run(
        initialSelection: Set<ID> = []
    ) throws -> TerminalInteractiveListResult<Item, ID> {
        let session = try TerminalSession(
            options: TerminalSession.Options(
                useAlternateScreen: configuration.useAlternateScreen,
                hideCursor: configuration.hideCursor,
                useRawMode: true,
                restoreOnInterrupt: true,
                outputStream: configuration.outputStream
            )
        )

        defer {
            session.restore()
        }

        var renderer = TerminalInteractiveListRenderer<Item, ID>(
            configuration: configuration
        )

        guard !items.isEmpty else {
            renderer.render(
                lines: renderedLines(
                    navigator: TerminalListNavigator(
                        count: 0,
                        selectedIndex: 0,
                        wrapMode: configuration.wrapMode
                    ),
                    selection: TerminalSelectionSet<ID>()
                )
            )

            let result = TerminalInteractiveListResult<Item, ID>.cancelled

            renderer.finish(
                result: result,
                summary: summaryRenderer
            )

            return result
        }

        let reader = TerminalKeyReader()
        var navigator = TerminalListNavigator(
            count: items.count,
            selectedIndex: firstEnabledIndex() ?? 0,
            wrapMode: configuration.wrapMode
        )
        var selection = TerminalSelectionSet<ID>(
            selected: initialSelection.filter { id in
                items.contains { item in
                    idProvider(item) == id && enabledProvider(item)
                }
            }
        )

        while true {
            renderer.render(
                lines: renderedLines(
                    navigator: navigator,
                    selection: selection
                )
            )

            let key = reader.readKey()

            switch key {
            case .up, .control("P"):
                moveSelection(
                    navigator: &navigator,
                    direction: -1
                )

            case .down, .control("N"):
                moveSelection(
                    navigator: &navigator,
                    direction: 1
                )

            case .space, .controlSpace:
                toggleCurrent(
                    navigator: navigator,
                    selection: &selection
                )

            case .enter:
                let result = acceptedResult(
                    navigator: navigator,
                    selection: selection
                )

                renderer.finish(
                    result: result,
                    summary: summaryRenderer
                )

                return result

            case .escape, .control("C"), .control("D"), .char("q"):
                let result = TerminalInteractiveListResult<Item, ID>.cancelled

                renderer.finish(
                    result: result,
                    summary: summaryRenderer
                )

                return result

            default:
                break
            }
        }
    }

    private func firstEnabledIndex() -> Int? {
        items.indices.first { index in
            enabledProvider(
                items[index]
            )
        }
    }

    private func moveSelection(
        navigator: inout TerminalListNavigator,
        direction: Int
    ) {
        guard !items.isEmpty else {
            return
        }

        guard items.contains(where: enabledProvider) else {
            return
        }

        repeat {
            if direction < 0 {
                navigator.moveUp()
            } else {
                navigator.moveDown()
            }

            if let index = navigator.selection,
               enabledProvider(items[index]) {
                return
            }
        } while true
    }

    private func toggleCurrent(
        navigator: TerminalListNavigator,
        selection: inout TerminalSelectionSet<ID>
    ) {
        guard let index = navigator.selection else {
            return
        }

        let item = items[index]

        guard enabledProvider(item) else {
            return
        }

        let id = idProvider(
            item
        )

        if configuration.allowsMultipleSelection {
            selection.toggle(
                id
            )
        } else {
            selection.clear()
            selection.select(
                id
            )
        }
    }

    private func acceptedResult(
        navigator: TerminalListNavigator,
        selection: TerminalSelectionSet<ID>
    ) -> TerminalInteractiveListResult<Item, ID> {
        let current: Item?

        if let index = navigator.selection,
           enabledProvider(items[index]) {
            current = items[index]
        } else {
            current = nil
        }

        if configuration.allowsMultipleSelection {
            return .accepted(
                current: current,
                selected: selectedItems(
                    selection: selection
                ),
                selectedIDs: selectedIDs(
                    selection: selection
                )
            )
        }

        if let current {
            let id = idProvider(
                current
            )

            return .accepted(
                current: current,
                selected: [
                    current
                ],
                selectedIDs: [
                    id
                ]
            )
        }

        return .accepted(
            current: nil,
            selected: [],
            selectedIDs: []
        )
    }

    private func selectedItems(
        selection: TerminalSelectionSet<ID>
    ) -> [Item] {
        items.filter { item in
            selection.contains(
                idProvider(
                    item
                )
            ) && enabledProvider(item)
        }
    }

    private func selectedIDs(
        selection: TerminalSelectionSet<ID>
    ) -> [ID] {
        items.compactMap { item in
            let id = idProvider(
                item
            )

            guard selection.contains(id),
                  enabledProvider(item) else {
                return nil
            }

            return id
        }
    }

    private func renderedLines(
        navigator: TerminalListNavigator,
        selection: TerminalSelectionSet<ID>
    ) -> [String] {
        var lines: [String] = []

        lines.append(
            configuration.title + "\n"
        )

        if !configuration.instructions.isEmpty {
            lines.append(
                configuration.instructions + "\n"
            )
        }

        lines.append(
            "\n"
        )

        guard !items.isEmpty else {
            lines.append(
                "(no items)\n"
            )
            return lines
        }

        for index in items.indices {
            let item = items[index]
            let id = idProvider(
                item
            )
            let isCurrent = navigator.selection == index
            let isSelected = selection.contains(
                id
            )
            let isEnabled = enabledProvider(
                item
            )

            let row = TerminalInteractiveListRow(
                item: item,
                id: id,
                index: index,
                isCurrent: isCurrent,
                isSelected: isSelected,
                isEnabled: isEnabled
            )

            var rendered = rowRenderer(
                row
            )

            if !isEnabled {
                rendered = rendered.ansi(
                    .dim
                )
            } else if isCurrent {
                switch configuration.currentRowStyle {
                case .inverse:
                    rendered = rendered.ansi(
                        .inverse
                    )

                case .none:
                    break
                }
            }

            lines.append(
                rendered
            )
        }

        return lines
    }
}

private struct TerminalInteractiveListRenderer<Item: Sendable, ID: Hashable & Sendable> {
    var configuration: TerminalInteractiveListConfiguration
    var previousRenderedRowCount: Int = 0

    mutating func render(
        lines: [String]
    ) {
        switch configuration.presentation {
        case .fullscreen:
            Terminal.clearScreen(
                to: configuration.outputStream
            )
            Terminal.moveCursor(
                line: 1,
                column: 1,
                to: configuration.outputStream
            )

        case .inline:
            if previousRenderedRowCount > 0 {
                TerminalScreenRegion.moveUp(
                    previousRenderedRowCount,
                    stream: configuration.outputStream
                )
                TerminalScreenRegion.clearLinesFromCursor(
                    count: previousRenderedRowCount,
                    stream: configuration.outputStream
                )
            }
        }

        for line in lines {
            Terminal.write(
                line,
                to: configuration.outputStream
            )
        }

        previousRenderedRowCount = renderedRowCount(
            for: lines
        )

        Terminal.flush(
            configuration.outputStream
        )
    }

    mutating func finish(
        result: TerminalInteractiveListResult<Item, ID>,
        summary: TerminalInteractiveList<Item, ID>.SummaryRenderer?
    ) {
        switch configuration.completionPresentation {
        case .clear:
            clearCurrentRegion()

        case .leaveLastFrame:
            return

        case .leaveSummary:
            clearCurrentRegion()

            if let summary {
                Terminal.write(
                    summary(result),
                    to: configuration.outputStream
                )
                Terminal.flush(
                    configuration.outputStream
                )
            }
        }
    }

    private mutating func clearCurrentRegion() {
        switch configuration.presentation {
        case .fullscreen:
            Terminal.clearScreen(
                to: configuration.outputStream
            )
            Terminal.moveCursor(
                line: 1,
                column: 1,
                to: configuration.outputStream
            )

        case .inline:
            if previousRenderedRowCount > 0 {
                TerminalScreenRegion.moveUp(
                    previousRenderedRowCount,
                    stream: configuration.outputStream
                )
                TerminalScreenRegion.clearLinesFromCursor(
                    count: previousRenderedRowCount,
                    stream: configuration.outputStream
                )
            }
        }

        previousRenderedRowCount = 0

        Terminal.flush(
            configuration.outputStream
        )
    }

    private func renderedRowCount(
        for lines: [String]
    ) -> Int {
        let columns = max(
            1,
            Terminal.size(
                for: configuration.outputStream
            ).columns
        )

        return lines.reduce(0) { count, line in
            count + renderedRowCount(
                for: line,
                columns: columns
            )
        }
    }

    private func renderedRowCount(
        for line: String,
        columns: Int
    ) -> Int {
        let stripped = stripANSI(
            line
        )

        var pieces = stripped.components(
            separatedBy: "\n"
        )

        if stripped.hasSuffix("\n"),
           !pieces.isEmpty {
            pieces.removeLast()
        }

        guard !pieces.isEmpty else {
            return 1
        }

        return pieces.reduce(0) { count, piece in
            let visibleCount = piece.count
            let rowCount = max(
                1,
                (visibleCount + columns - 1) / columns
            )

            return count + rowCount
        }
    }
}
