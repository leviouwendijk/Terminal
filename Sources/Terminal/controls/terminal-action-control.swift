public enum TerminalActionControlEvent:
    Sendable,
    Hashable
{
    case accepted
}

public struct TerminalActionControl:
    Sendable,
    Hashable
{
    public var symbol: String
    public var label: String?
    public var isEnabled: Bool
    public var isActive: Bool

    public init(
        symbol: String,
        label: String? = nil,
        isEnabled: Bool = true,
        isActive: Bool = false
    ) {
        self.symbol = symbol
        self.label = label
        self.isEnabled = isEnabled
        self.isActive = isActive
    }

    public func handle(
        _ key: TerminalKey
    ) -> TerminalActionControlEvent? {
        guard isEnabled else {
            return nil
        }

        switch key {
        case .enter,
             .space:
            return .accepted

        default:
            return nil
        }
    }

    public func render(
        focused: Bool,
        theme: TerminalTheme = .standard
    ) -> String {
        let body = if let label,
                      !label.isEmpty
        {
            "\(symbol) \(label)"
        } else {
            symbol
        }

        let rendered = "[\(body)]"
        let style: TerminalStyle

        if !isEnabled {
            style = theme.disabled
        } else if focused {
            style = theme.cursor
        } else if isActive {
            style = theme.warning
        } else {
            style = theme.value
        }

        return style.apply(
            rendered
        )
    }
}
