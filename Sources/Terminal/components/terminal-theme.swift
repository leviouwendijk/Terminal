public struct TerminalTheme: Sendable, Hashable {
    public var title: TerminalStyle
    public var heading: TerminalStyle
    public var label: TerminalStyle
    public var value: TerminalStyle
    public var caption: TerminalStyle
    public var success: TerminalStyle
    public var warning: TerminalStyle
    public var failure: TerminalStyle
    public var cursor: TerminalStyle
    public var disabled: TerminalStyle

    public init(
        title: TerminalStyle = .bold,
        heading: TerminalStyle = .bold,
        label: TerminalStyle = .dim,
        value: TerminalStyle = .none,
        caption: TerminalStyle = .dim,
        success: TerminalStyle = .init(.green),
        warning: TerminalStyle = .init(.yellow),
        failure: TerminalStyle = .init(.red),
        cursor: TerminalStyle = .bold,
        disabled: TerminalStyle = .dim
    ) {
        self.title = title
        self.heading = heading
        self.label = label
        self.value = value
        self.caption = caption
        self.success = success
        self.warning = warning
        self.failure = failure
        self.cursor = cursor
        self.disabled = disabled
    }

    public static let standard = TerminalTheme()

    public static let plain = TerminalTheme(
        title: .none,
        heading: .none,
        label: .none,
        value: .none,
        caption: .none,
        success: .none,
        warning: .none,
        failure: .none,
        cursor: .none,
        disabled: .none
    )
}
