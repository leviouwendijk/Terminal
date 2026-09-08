import Swim

public typealias TerminalInteractionMode = Swim.Mode
public typealias TerminalMotion = Swim.Motion
public typealias TerminalInsertionPlacement = Swim.InsertionPlacement

public enum TerminalInteractionAction:
    Sendable,
    Codable,
    Hashable
{
    case literal(TerminalKey)
    case motion(TerminalMotion)
    case command(TerminalCommand)
    case enterInsert(TerminalInsertionPlacement)
    case enterBlockInsert(TerminalBlockInsertOperation)
    case enterVisual(TerminalSelectionKind)
    case returnToNormal
    case activate
    case delete
    case copy
    case change
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
    public private(set) var visualSelectionKind: TerminalSelectionKind?

    private var commandInterpreter: TerminalCommandInterpreter

    public init(
        mode: TerminalInteractionMode = .normal
    ) {
        self.mode = mode
        self.visualSelectionKind = mode == .visual
            ? .character
            : nil
        self.commandInterpreter = TerminalCommandInterpreter()
    }

    public mutating func setMode(
        _ mode: TerminalInteractionMode
    ) {
        self.mode = mode
        self.visualSelectionKind = mode == .visual
            ? .character
            : nil
        commandInterpreter.reset()
    }

    public mutating func handle(
        _ key: TerminalKey
    ) -> TerminalInteractionResult {
        if mode != .insert,
           mode != .replace
        {
            let shouldRouteCommand =
                commandInterpreter.state.isPending
                || isCommandGrammarKey(
                    key
                )

            if shouldRouteCommand {
                switch commandInterpreter.handle(
                    key
                ) {
                case .pending:
                    return .consumed

                case .command(let command):
                    return .action(
                        .command(
                            command
                        )
                    )

                case .cancelled:
                    return .consumed

                case .unhandled:
                    break
                }
            }
        } else {
            commandInterpreter.reset()
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

        case .replace:
            return handleInsert(
                key
            )

        case .visual:
            return handleVisual(
                key
            )
        }
    }

    private func isCommandGrammarKey(
        _ key: TerminalKey
    ) -> Bool {
        switch key {
        case .left,
             .right,
             .up,
             .down,
             .home,
             .end,
             .pageUp,
             .pageDown:
            return true

        case .char(let character):
            guard character.count == 1 else {
                return false
            }

            if "0123456789hjklbwe$gG".contains(
                character
            ) {
                return true
            }

            return mode == .normal
                && "dcyrDCSspPIAoORJ~><".contains(
                    character
                )

        default:
            return false
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
            visualSelectionKind = .character
            return .action(
                .enterVisual(
                    .character
                )
            )

        case .char("V"):
            mode = .visual
            visualSelectionKind = .line
            return .action(
                .enterVisual(
                    .line
                )
            )

        case .control("V"):
            mode = .visual
            visualSelectionKind = .block
            return .action(
                .enterVisual(
                    .block
                )
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

    private mutating func handleVisualKind(
        _ kind: TerminalSelectionKind
    ) -> TerminalInteractionResult {
        if visualSelectionKind == kind {
            mode = .normal
            visualSelectionKind = nil

            return .action(
                .returnToNormal
            )
        }

        visualSelectionKind = kind

        return .action(
            .enterVisual(
                kind
            )
        )
    }

    private mutating func handleVisual(
        _ key: TerminalKey
    ) -> TerminalInteractionResult {
        switch key {
        case .escape:
            mode = .normal
            visualSelectionKind = nil
            return .action(
                .returnToNormal
            )

        case .char("v"):
            return handleVisualKind(
                .character
            )

        case .char("V"):
            return handleVisualKind(
                .line
            )

        case .control("V"):
            return handleVisualKind(
                .block
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
            visualSelectionKind = nil
            return .action(
                .delete
            )

        case .char("y"):
            mode = .normal
            visualSelectionKind = nil
            return .action(
                .copy
            )

        case .char("c"):
            if visualSelectionKind == .block {
                mode = .insert
                visualSelectionKind = nil

                return .action(
                    .enterBlockInsert(
                        .change
                    )
                )
            }

            mode = .normal
            visualSelectionKind = nil
            return .action(
                .change
            )

        case .char("I"):
            guard visualSelectionKind == .block else {
                return .unhandled
            }

            mode = .insert
            visualSelectionKind = nil
            return .action(
                .enterBlockInsert(
                    .insertBefore
                )
            )

        case .char("A"):
            guard visualSelectionKind == .block else {
                return .unhandled
            }

            mode = .insert
            visualSelectionKind = nil
            return .action(
                .enterBlockInsert(
                    .insertAfter
                )
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
