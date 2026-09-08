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
    public var placeholder: String
    public var placeholderStyle: TerminalStyle

    public init(
        editor: TerminalTextEditor = TerminalTextEditor(),
        sizePolicy: TerminalTextSurfaceSizePolicy = .init(),
        presentation: TerminalTextSurfacePresentation = .compact,
        placeholder: String = "",
        placeholderStyle: TerminalStyle = .dim
    ) {
        self.editor = editor
        self.sizePolicy = sizePolicy
        self.presentation = presentation
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
        TerminalTextLayout(
            text: editor.buffer.text,
            columns: max(
                1,
                columns
            )
        ).rows.count
    }

    public func compactRows(
        columns: Int
    ) -> Int {
        sizePolicy.rows(
            forContentRows: contentRowCount(
                columns: columns
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

        editor.render(
            into: &frame,
            in: region,
            isFocused: isFocused
        )

        guard editor.buffer.text.isEmpty,
              !placeholder.isEmpty else {
            return
        }

        frame.write(
            placeholderStyle.apply(
                TerminalDisplay.clipped(
                    placeholder,
                    columns: region.columns
                )
            ),
            in: TerminalRegion(
                top: region.top,
                leading: region.leading,
                rows: 1,
                columns: region.columns
            )
        )
    }
}
