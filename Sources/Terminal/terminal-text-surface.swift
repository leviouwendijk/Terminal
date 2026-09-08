import Swim

public enum TerminalTextSurfacePresentation:
    Sendable,
    Hashable
{
    case compact
    case expanded
}

public struct TerminalTextSurfaceSizePolicy:
    Sendable,
    Hashable
{
    public var minimumRows: Int
    public var maximumRows: Int

    public init(
        minimumRows: Int = 1,
        maximumRows: Int = 6
    ) {
        let minimumRows = max(
            1,
            minimumRows
        )

        self.minimumRows = minimumRows
        self.maximumRows = max(
            minimumRows,
            maximumRows
        )
    }

    public func rows(
        forContentRows contentRows: Int
    ) -> Int {
        min(
            maximumRows,
            max(
                minimumRows,
                contentRows
            )
        )
    }
}

public struct TerminalTextSurface:
    Sendable,
    Hashable
{
    public private(set) var editor: TerminalTextEditor
    public var sizePolicy: TerminalTextSurfaceSizePolicy
    public private(set) var presentation: TerminalTextSurfacePresentation
    public var compactEditorPresentation: TerminalTextEditorPresentation
    public var expandedEditorPresentation: TerminalTextEditorPresentation
    public var placeholder: String
    public var placeholderStyle: TerminalStyle

    public init(
        editor: TerminalTextEditor = TerminalTextEditor(),
        sizePolicy: TerminalTextSurfaceSizePolicy = .init(),
        presentation: TerminalTextSurfacePresentation = .compact,
        compactEditorPresentation: TerminalTextEditorPresentation = .plain,
        expandedEditorPresentation: TerminalTextEditorPresentation = .plain,
        placeholder: String = "",
        placeholderStyle: TerminalStyle = .dim
    ) {
        self.editor = editor
        self.sizePolicy = sizePolicy
        self.presentation = presentation
        self.compactEditorPresentation = compactEditorPresentation
        self.expandedEditorPresentation = expandedEditorPresentation
        self.placeholder = placeholder
        self.placeholderStyle = placeholderStyle
    }

    public var text: String {
        editor.buffer.text
    }

    public var mode: Swim.Mode {
        editor.mode
    }

    public var viewport: TerminalViewport {
        editor.viewport
    }

    public var editorPresentation: TerminalTextEditorPresentation {
        editorPresentation(
            for: presentation
        )
    }

    public mutating func handle(
        _ event: TerminalInputEvent
    ) -> TerminalTextEditorEvent? {
        editor.handle(
            event
        )
    }

    public mutating func handle(
        _ key: TerminalKey
    ) -> TerminalTextEditorEvent? {
        editor.handle(
            key
        )
    }

    public mutating func replace(
        with text: String,
        cursorOffset: Int? = nil
    ) {
        editor.replace(
            with: text,
            cursorOffset: cursorOffset
        )
    }

    public mutating func clear() {
        editor.replace(
            with: ""
        )
    }

    public mutating func setMode(
        _ mode: Swim.Mode
    ) {
        editor.setMode(
            mode
        )
    }

    public mutating func setPresentation(
        _ presentation: TerminalTextSurfacePresentation
    ) {
        self.presentation = presentation
    }

    public mutating func togglePresentation() {
        presentation = presentation == .compact
            ? .expanded
            : .compact
    }

    public func contentRowCount(
        columns: Int
    ) -> Int {
        contentRowCount(
            columns: columns,
            presentation: presentation
        )
    }

    public func compactRows(
        columns: Int
    ) -> Int {
        sizePolicy.rows(
            forContentRows: contentRowCount(
                columns: columns,
                presentation: .compact
            )
        )
    }

    public func resolvedRows(
        columns: Int,
        availableRows: Int
    ) -> Int {
        let availableRows = max(
            0,
            availableRows
        )

        guard availableRows > 0 else {
            return 0
        }

        switch presentation {
        case .compact:
            return min(
                availableRows,
                compactRows(
                    columns: columns
                )
            )

        case .expanded:
            return availableRows
        }
    }

    public mutating func render(
        into frame: inout TerminalFrame,
        in region: TerminalRegion,
        isFocused: Bool = true
    ) {
        guard !region.isEmpty else {
            return
        }

        let editorPresentation = self.editorPresentation

        editor.render(
            into: &frame,
            in: region,
            isFocused: isFocused,
            presentation: editorPresentation
        )

        guard editor.buffer.text.isEmpty,
              !placeholder.isEmpty else {
            return
        }

        let gutterColumns = editorPresentation.gutterColumns(
            lineCount: editor.buffer.lineCount,
            availableColumns: region.columns
        )
        let placeholderColumns = max(
            0,
            region.columns - gutterColumns
        )

        guard placeholderColumns > 0 else {
            return
        }

        frame.write(
            placeholderStyle.apply(
                TerminalDisplay.clipped(
                    placeholder,
                    columns: placeholderColumns
                )
            ),
            in: TerminalRegion(
                top: region.top,
                leading: region.leading + gutterColumns,
                rows: 1,
                columns: placeholderColumns
            )
        )
    }

    private func editorPresentation(
        for presentation: TerminalTextSurfacePresentation
    ) -> TerminalTextEditorPresentation {
        switch presentation {
        case .compact:
            return compactEditorPresentation

        case .expanded:
            return expandedEditorPresentation
        }
    }

    private func contentRowCount(
        columns: Int,
        presentation: TerminalTextSurfacePresentation
    ) -> Int {
        let columns = max(
            1,
            columns
        )
        let editorPresentation = editorPresentation(
            for: presentation
        )
        let gutterColumns = editorPresentation.gutterColumns(
            lineCount: editor.buffer.lineCount,
            availableColumns: columns
        )

        return TerminalTextLayout(
            text: editor.buffer.text,
            columns: max(
                1,
                columns - gutterColumns
            )
        ).rows.count
    }
}
