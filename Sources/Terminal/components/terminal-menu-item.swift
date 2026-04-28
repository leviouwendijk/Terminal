public struct TerminalMenuItem<ID: Hashable & Sendable>: Sendable, Hashable {
    public var id: ID
    public var title: String
    public var caption: String?
    public var isEnabled: Bool

    public init(
        id: ID,
        title: String,
        caption: String? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.caption = caption
        self.isEnabled = isEnabled
    }

    public var rowContent: TerminalMenuRowContent {
        TerminalMenuRowContent(
            title: title,
            caption: caption
        )
    }
}
