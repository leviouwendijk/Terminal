public enum TerminalKey: Sendable, Codable, Hashable, CustomStringConvertible {
    case up
    case down
    case left
    case right
    case home
    case end
    case pageUp
    case pageDown
    case insert
    case delete

    case enter
    case escape
    case backspace
    case tab
    case space
    case controlSpace

    case control(String)
    case char(String)
    case unknown([UInt8])

    public var description: String {
        switch self {
        case .up:
            return "up"

        case .down:
            return "down"

        case .left:
            return "left"

        case .right:
            return "right"

        case .home:
            return "home"

        case .end:
            return "end"

        case .pageUp:
            return "pageUp"

        case .pageDown:
            return "pageDown"

        case .insert:
            return "insert"

        case .delete:
            return "delete"

        case .enter:
            return "enter"

        case .escape:
            return "escape"

        case .backspace:
            return "backspace"

        case .tab:
            return "tab"

        case .space:
            return "space"

        case .controlSpace:
            return "controlSpace"

        case .control(let key):
            return "control(\(key))"

        case .char(let key):
            return "char(\(key))"

        case .unknown(let bytes):
            return "unknown(\(bytes.map(String.init).joined(separator: ",")))"
        }
    }

    public var isVerticalPrevious: Bool {
        switch self {
        case .up, .control("P"):
            return true

        default:
            return false
        }
    }

    public var isVerticalNext: Bool {
        switch self {
        case .down, .control("N"):
            return true

        default:
            return false
        }
    }

    public var isExitLike: Bool {
        switch self {
        case .escape, .control("C"), .control("D"):
            return true

        default:
            return false
        }
    }
}
