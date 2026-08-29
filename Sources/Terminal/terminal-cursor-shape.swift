public enum TerminalCursorShape:
    Int,
    Sendable,
    Codable,
    Hashable
{
    case automatic = 0
    case block = 2
    case underline = 4
    case bar = 6

    public var escapeSequence: String {
        "\u{001B}[\(rawValue) q"
    }
}
