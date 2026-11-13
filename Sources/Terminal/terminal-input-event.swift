public enum TerminalInputEvent:
    Sendable,
    Codable,
    Hashable
{
    case key(TerminalKey)
    case keyStroke(TerminalKeyStroke)
    case paste(String)
    case mouse(TerminalMouseEvent)

    public var keyStroke: TerminalKeyStroke? {
        switch self {
        case .key(let key):
            return TerminalKeyStroke(
                key: key
            )

        case .keyStroke(let keyStroke):
            return keyStroke

        case .paste, .mouse:
            return nil
        }
    }

    public var legacyKey: TerminalKey {
        switch self {
        case .key(let key):
            return key

        case .keyStroke(let keyStroke):
            return keyStroke.key

        case .paste(let text):
            return .char(
                text
            )

        case .mouse:
            return .unknown([])
        }
    }
}
