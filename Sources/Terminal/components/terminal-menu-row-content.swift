public struct TerminalMenuRowContent: Sendable, Hashable {
    public var title: String
    public var caption: String?

    public init(
        title: String,
        caption: String? = nil
    ) {
        self.title = title
        self.caption = caption
    }

    public func render(
        isCurrent: Bool,
        isEnabled: Bool = true,
        theme: TerminalTheme = .standard,
        width: Int? = nil
    ) -> String {
        var lines: [String] = []

        appendTitle(
            to: &lines,
            isCurrent: isCurrent,
            isEnabled: isEnabled,
            theme: theme,
            width: width
        )

        appendCaption(
            to: &lines,
            isEnabled: isEnabled,
            theme: theme,
            width: width
        )

        return lines.joined(
            separator: "\n"
        ) + "\n"
    }

    private func appendTitle(
        to lines: inout [String],
        isCurrent: Bool,
        isEnabled: Bool,
        theme: TerminalTheme,
        width: Int?
    ) {
        let cursor = isCurrent
            ? theme.cursor.apply(">")
            : " "

        let style: TerminalStyle

        if !isEnabled {
            style = theme.disabled
        } else if isCurrent {
            style = theme.cursor
        } else {
            style = theme.value
        }

        let prefix = "\(cursor) "
        let continuationPrefix = "  "
        let wrapped = wrappedLines(
            title,
            width: width,
            indent: 2
        )

        guard let first = wrapped.first else {
            lines.append(
                prefix
            )
            return
        }

        lines.append(
            prefix + style.apply(first)
        )

        for line in wrapped.dropFirst() {
            lines.append(
                continuationPrefix + style.apply(line)
            )
        }
    }

    private func appendCaption(
        to lines: inout [String],
        isEnabled: Bool,
        theme: TerminalTheme,
        width: Int?
    ) {
        guard let caption,
              !caption.isEmpty else {
            return
        }

        let style = isEnabled
            ? theme.caption
            : theme.disabled

        let prefix = "    "
        let wrapped = wrappedLines(
            caption,
            width: width,
            indent: 4
        )

        for line in wrapped {
            lines.append(
                prefix + style.apply(line)
            )
        }
    }

    private func wrappedLines(
        _ text: String,
        width: Int?,
        indent: Int
    ) -> [String] {
        guard let width else {
            return [
                text
            ]
        }

        return TerminalTextWrap.lines(
            text,
            width: max(
                1,
                width - indent
            )
        )
    }
}
