public enum TerminalInteractionMode:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case normal
    case insert
    case visual
}

public enum TerminalMotion:
    Sendable,
    Codable,
    Hashable
{
    case left
    case right
    case up
    case down
    case wordBackward
    case wordForward
    case wordEnd
    case lineStart
    case lineEnd
    case documentStart
    case documentEnd
    case pageUp
    case pageDown
}

public enum TerminalInsertionPlacement:
    Sendable,
    Codable,
    Hashable
{
    case beforeCursor
    case afterCursor
}

public enum TerminalInteractionAction:
    Sendable,
    Codable,
    Hashable
{
    case literal(TerminalKey)
    case motion(TerminalMotion)
    case enterInsert(TerminalInsertionPlacement)
    case enterVisual
    case returnToNormal
    case activate
    case delete
    case copy
}

public enum TerminalInteractionResult:
    Sendable,
    Codable,
    Hashable
{
    case consumed
    case action(TerminalInteractionAction)
    case unhandled
}

public struct TerminalModalInteraction:
    Sendable,
    Codable,
    Hashable
{
    public private(set) var mode: TerminalInteractionMode

    private var isWaitingForG: Bool

    public init(
        mode: TerminalInteractionMode = .normal
    ) {
        self.mode = mode
        self.isWaitingForG = false
    }

    public mutating func setMode(
        _ mode: TerminalInteractionMode
    ) {
        self.mode = mode
        isWaitingForG = false
    }

    public mutating func handle(
        _ key: TerminalKey
    ) -> TerminalInteractionResult {
        if isWaitingForG {
            isWaitingForG = false

            if key == .char("g"),
               mode != .insert {
                return .action(
                    .motion(
                        .documentStart
                    )
                )
            }
        }

        switch mode {
        case .normal:
            return handleNormal(
                key
            )

        case .insert:
            return handleInsert(
                key
            )

        case .visual:
            return handleVisual(
                key
            )
        }
    }

    private mutating func handleNormal(
        _ key: TerminalKey
    ) -> TerminalInteractionResult {
        switch key {
        case .char("h"),
             .left:
            return .action(
                .motion(
                    .left
                )
            )

        case .char("j"),
             .down:
            return .action(
                .motion(
                    .down
                )
            )

        case .char("k"),
             .up:
            return .action(
                .motion(
                    .up
                )
            )

        case .char("l"),
             .right:
            return .action(
                .motion(
                    .right
                )
            )

        case .char("b"):
            return .action(
                .motion(
                    .wordBackward
                )
            )

        case .char("w"):
            return .action(
                .motion(
                    .wordForward
                )
            )

        case .char("e"):
            return .action(
                .motion(
                    .wordEnd
                )
            )

        case .char("0"),
             .home:
            return .action(
                .motion(
                    .lineStart
                )
            )

        case .char("$"),
             .end:
            return .action(
                .motion(
                    .lineEnd
                )
            )

        case .pageUp:
            return .action(
                .motion(
                    .pageUp
                )
            )

        case .pageDown:
            return .action(
                .motion(
                    .pageDown
                )
            )

        case .char("g"):
            isWaitingForG = true
            return .consumed

        case .char("G"):
            return .action(
                .motion(
                    .documentEnd
                )
            )

        case .char("i"):
            mode = .insert
            return .action(
                .enterInsert(
                    .beforeCursor
                )
            )

        case .char("a"):
            mode = .insert
            return .action(
                .enterInsert(
                    .afterCursor
                )
            )

        case .char("v"):
            mode = .visual
            return .action(
                .enterVisual
            )

        case .char("x"),
             .delete:
            return .action(
                .delete
            )

        case .char("y"):
            return .action(
                .copy
            )

        case .enter:
            return .action(
                .activate
            )

        case .escape:
            return .unhandled

        default:
            return .unhandled
        }
    }

    private mutating func handleInsert(
        _ key: TerminalKey
    ) -> TerminalInteractionResult {
        switch key {
        case .escape:
            mode = .normal
            return .action(
                .returnToNormal
            )

        case .left:
            return .action(
                .motion(
                    .left
                )
            )

        case .right:
            return .action(
                .motion(
                    .right
                )
            )

        case .up:
            return .action(
                .motion(
                    .up
                )
            )

        case .down:
            return .action(
                .motion(
                    .down
                )
            )

        case .home:
            return .action(
                .motion(
                    .lineStart
                )
            )

        case .end:
            return .action(
                .motion(
                    .lineEnd
                )
            )

        case .pageUp:
            return .action(
                .motion(
                    .pageUp
                )
            )

        case .pageDown:
            return .action(
                .motion(
                    .pageDown
                )
            )

        default:
            return .action(
                .literal(
                    key
                )
            )
        }
    }

    private mutating func handleVisual(
        _ key: TerminalKey
    ) -> TerminalInteractionResult {
        switch key {
        case .escape,
             .char("v"):
            mode = .normal
            return .action(
                .returnToNormal
            )

        case .char("h"),
             .left:
            return .action(
                .motion(
                    .left
                )
            )

        case .char("j"),
             .down:
            return .action(
                .motion(
                    .down
                )
            )

        case .char("k"),
             .up:
            return .action(
                .motion(
                    .up
                )
            )

        case .char("l"),
             .right:
            return .action(
                .motion(
                    .right
                )
            )

        case .char("b"):
            return .action(
                .motion(
                    .wordBackward
                )
            )

        case .char("w"):
            return .action(
                .motion(
                    .wordForward
                )
            )

        case .char("e"):
            return .action(
                .motion(
                    .wordEnd
                )
            )

        case .char("0"),
             .home:
            return .action(
                .motion(
                    .lineStart
                )
            )

        case .char("$"),
             .end:
            return .action(
                .motion(
                    .lineEnd
                )
            )

        case .pageUp:
            return .action(
                .motion(
                    .pageUp
                )
            )

        case .pageDown:
            return .action(
                .motion(
                    .pageDown
                )
            )

        case .char("g"):
            isWaitingForG = true
            return .consumed

        case .char("G"):
            return .action(
                .motion(
                    .documentEnd
                )
            )

        case .char("d"),
             .char("x"),
             .delete:
            mode = .normal
            return .action(
                .delete
            )

        case .char("y"):
            mode = .normal
            return .action(
                .copy
            )

        case .enter:
            return .action(
                .activate
            )

        default:
            return .unhandled
        }
    }
}
