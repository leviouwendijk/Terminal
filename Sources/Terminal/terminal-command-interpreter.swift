import Swim

public typealias TerminalCommandTiming = Swim.CommandTiming
public typealias TerminalCommandInterpreter = Swim.CommandInterpreter

public extension Swim.CommandInterpreter {
    mutating func handle(
        _ key: TerminalKey
    ) -> Swim.CommandInterpretation {
        handle(
            key.swimInput
        )
    }

    mutating func handle(
        _ key: TerminalKey,
        atNanoseconds now: UInt64
    ) -> Swim.CommandInterpretation {
        handle(
            key.swimInput,
            atNanoseconds: now
        )
    }
}
