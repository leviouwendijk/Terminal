public struct TerminalTextPosition:
    Sendable,
    Codable,
    Hashable
{
    public var row: Int
    public var column: Int

    public init(
        row: Int,
        column: Int
    ) {
        self.row = max(
            0,
            row
        )
        self.column = max(
            0,
            column
        )
    }
}
