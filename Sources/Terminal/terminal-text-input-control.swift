public struct TerminalTextInputControl:
    Sendable,
    Hashable
{
    public private(set) var input: TerminalTextInput
    public var prompt: String
    public var placeholder: String
    public var placeholderStyle: TerminalStyle

    public init(
        input: TerminalTextInput = TerminalTextInput(),
        prompt: String = "> ",
        placeholder: String = "",
        placeholderStyle: TerminalStyle = .dim
    ) {
        self.input = input
        self.prompt = prompt
        self.placeholder = placeholder
        self.placeholderStyle = placeholderStyle
    }

    public mutating func handle(
        _ key: TerminalKey
    ) -> TerminalTextInputEvent? {
        input.handle(
            key
        )
    }

    public mutating func replace(
        with text: String,
        cursorOffset: Int? = nil
    ) {
        input.replace(
            with: text,
            cursorOffset: cursorOffset
        )
    }

    public mutating func clear() {
        input.clear()
    }

    public func render(
        into frame: inout TerminalFrame,
        in region: TerminalRegion,
        isFocused: Bool
    ) {
        guard region.rows > 0,
              region.columns > 0 else {
            return
        }

        let promptWidth = TerminalDisplay.width(
            of: prompt
        )
        let contentColumns = max(
            0,
            region.columns - promptWidth
        )
        let visible = visibleInput(
            columns: contentColumns
        )
        let content: String

        if input.isEmpty,
           !placeholder.isEmpty {
            content = placeholderStyle.apply(
                placeholder
            )
        } else {
            content = visible.text
        }

        frame.write(
            prompt + content,
            in: TerminalRegion(
                top: region.top,
                leading: region.leading,
                rows: 1,
                columns: region.columns
            )
        )

        guard isFocused else {
            return
        }

        frame.placeCursor(
            row: region.top,
            column:
                region.leading
                + min(
                    region.columns - 1,
                    promptWidth
                    + visible.cursorColumn
                )
        )
    }

    private func visibleInput(
        columns: Int
    ) -> (
        text: String,
        cursorColumn: Int
    ) {
        guard columns > 0 else {
            return (
                "",
                0
            )
        }

        let characters = Array(
            input.text
        )
        let cursor = min(
            max(
                0,
                input.cursorOffset
            ),
            characters.count
        )

        if TerminalDisplay.width(
            of: input.text
        ) <= columns {
            let before = String(
                characters[..<cursor]
            )

            return (
                input.text,
                min(
                    columns - 1,
                    TerminalDisplay.width(
                        of: before
                    )
                )
            )
        }

        var start = cursor
        var beforeWidth = 0
        let maximumBeforeWidth = max(
            0,
            columns - 1
        )

        while start > 0 {
            let character = String(
                characters[start - 1]
            )
            let width = TerminalDisplay.width(
                of: character
            )

            guard beforeWidth + width
                    <= maximumBeforeWidth else {
                break
            }

            start -= 1
            beforeWidth += width
        }

        var end = cursor
        var totalWidth = beforeWidth

        while end < characters.count {
            let character = String(
                characters[end]
            )
            let width = TerminalDisplay.width(
                of: character
            )

            guard totalWidth + width
                    <= columns else {
                break
            }

            totalWidth += width
            end += 1
        }

        return (
            String(
                characters[start..<end]
            ),
            beforeWidth
        )
    }
}
