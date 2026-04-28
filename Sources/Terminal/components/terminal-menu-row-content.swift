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
        theme: TerminalTheme = .standard
    ) -> String {
        let cursor = isCurrent
            ? theme.cursor.apply(">")
            : " "

        let renderedTitle: String

        if !isEnabled {
            renderedTitle = theme.disabled.apply(
                title
            )
        } else if isCurrent {
            renderedTitle = theme.cursor.apply(
                title
            )
        } else {
            renderedTitle = theme.value.apply(
                title
            )
        }

        var lines = [
            "\(cursor) \(renderedTitle)"
        ]

        if let caption,
           !caption.isEmpty {
            let renderedCaption = isEnabled
                ? theme.caption.apply(caption)
                : theme.disabled.apply(caption)

            lines.append(
                "  \(renderedCaption)"
            )
        }

        return lines.joined(
            separator: "\n"
        ) + "\n"
    }
}
