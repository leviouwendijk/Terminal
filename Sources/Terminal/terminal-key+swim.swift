import Swim

public extension TerminalKey {
    var swimInput: Swim.Input {
        switch self {
        case .up:
            return .up

        case .down:
            return .down

        case .left:
            return .left

        case .right:
            return .right

        case .home:
            return .home

        case .end:
            return .end

        case .pageUp:
            return .pageUp

        case .pageDown:
            return .pageDown

        case .insert:
            return .insert

        case .delete:
            return .delete

        case .enter:
            return .enter

        case .escape:
            return .escape

        case .backspace:
            return .backspace

        case .tab:
            return .tab

        case .space:
            return .space

        case .controlSpace:
            return .controlSpace

        case .control(let key):
            return .control(
                key
            )

        case .char(let key):
            return .char(
                key
            )

        case .unknown(_):
            return .unknown
        }
    }
}
