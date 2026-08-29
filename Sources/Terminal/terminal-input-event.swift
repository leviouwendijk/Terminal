public enum TerminalInputEvent:
    Sendable,
    Codable,
    Hashable
{
    case key(TerminalKey)
    case paste(String)

    public var legacyKey: TerminalKey {
        switch self {
        case .key(let key):
            return key

        case .paste(let text):
            return .char(
                text
            )
        }
    }
}
