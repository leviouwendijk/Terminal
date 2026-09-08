import Clipboard

public enum TerminalClipboardDestination:
    Sendable,
    Hashable
{
    case disabled
    case system
    case named(String)

    public func read() -> String? {
        switch self {
        case .disabled:
            return nil

        case .system:
            return Clipboard.system.read()

        case .named(let name):
            return Clipboard.register(
                name
            ).read()
        }
    }

    @discardableResult
    public func write(
        _ text: String
    ) -> Bool {
        switch self {
        case .disabled:
            return true

        case .system:
            return Clipboard.system.write(
                text
            )

        case .named(let name):
            return Clipboard.register(
                name
            ).write(
                text
            )
        }
    }
}
