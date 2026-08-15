public enum TerminalNavigationAxis:
    String,
    Sendable,
    Codable,
    Hashable
{
    case vertical
    case horizontal
}

public enum TerminalNavigationAction:
    String,
    Sendable,
    Codable,
    Hashable
{
    case previous
    case next
}

public enum TerminalNavigationDefaults {
    public static let verticalInstructions =
        "Move: Ctrl-P/Ctrl-N, ↑/↓, or k/j. "
        + "Select: Enter. Cancel: Esc/q."

    public static let horizontalInstructions =
        "Move: Ctrl-P/Ctrl-N, ←/→, or h/l. "
        + "Select: Enter. Cancel: Esc/q."
}

public extension TerminalKey {
    func navigationAction(
        on axis: TerminalNavigationAxis
    ) -> TerminalNavigationAction? {
        switch self {
        case .control("P"):
            return .previous

        case .control("N"):
            return .next

        default:
            break
        }

        switch axis {
        case .vertical:
            switch self {
            case .up,
                 .char("k"):
                return .previous

            case .down,
                 .char("j"):
                return .next

            default:
                return nil
            }

        case .horizontal:
            switch self {
            case .left,
                 .char("h"):
                return .previous

            case .right,
                 .char("l"):
                return .next

            default:
                return nil
            }
        }
    }

    var isVerticalPrevious: Bool {
        navigationAction(
            on: .vertical
        ) == .previous
    }

    var isVerticalNext: Bool {
        navigationAction(
            on: .vertical
        ) == .next
    }

    var isHorizontalPrevious: Bool {
        navigationAction(
            on: .horizontal
        ) == .previous
    }

    var isHorizontalNext: Bool {
        navigationAction(
            on: .horizontal
        ) == .next
    }
}
