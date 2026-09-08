public enum TerminalKeyBinding<Action: Sendable>:
    Sendable
{
    case key(TerminalKey)
    case action(Action)
    case consumed
}

public enum TerminalKeyResolution<Action: Sendable>:
    Sendable
{
    case key(TerminalKey)
    case action(Action)
    case consumed
}

public struct TerminalKeyMap<Action: Sendable>:
    Sendable
{
    private var bindings: [
        TerminalKey: TerminalKeyBinding<Action>
    ]
    private var keyStrokeBindings: [
        TerminalKeyStroke: TerminalKeyBinding<Action>
    ]

    public init(
        bindings: [
            TerminalKey: TerminalKeyBinding<Action>
        ] = [:],
        keyStrokeBindings: [
            TerminalKeyStroke: TerminalKeyBinding<Action>
        ] = [:]
    ) {
        self.bindings = bindings
        self.keyStrokeBindings = keyStrokeBindings
    }

    public var isEmpty: Bool {
        bindings.isEmpty
    }

    public func binding(
        for key: TerminalKey
    ) -> TerminalKeyBinding<Action>? {
        bindings[key]
    }

    public func binding(
        for keyStroke: TerminalKeyStroke
    ) -> TerminalKeyBinding<Action>? {
        keyStrokeBindings[keyStroke]
    }

    public mutating func remap(
        _ input: TerminalKey,
        to output: TerminalKey
    ) {
        bindings[input] = .key(
            output
        )
    }

    public mutating func remap(
        _ input: TerminalKeyStroke,
        to output: TerminalKey
    ) {
        keyStrokeBindings[input] = .key(
            output
        )
    }

    public mutating func bindAction(
        _ input: TerminalKey,
        to action: Action
    ) {
        bindings[input] = .action(
            action
        )
    }

    public mutating func bindAction(
        _ input: TerminalKeyStroke,
        to action: Action
    ) {
        keyStrokeBindings[input] = .action(
            action
        )
    }

    public mutating func consume(
        _ input: TerminalKey
    ) {
        bindings[input] = .consumed
    }

    public mutating func consume(
        _ input: TerminalKeyStroke
    ) {
        keyStrokeBindings[input] = .consumed
    }

    @discardableResult
    public mutating func remove(
        _ input: TerminalKey
    ) -> TerminalKeyBinding<Action>? {
        bindings.removeValue(
            forKey: input
        )
    }

    @discardableResult
    public mutating func remove(
        _ input: TerminalKeyStroke
    ) -> TerminalKeyBinding<Action>? {
        keyStrokeBindings.removeValue(
            forKey: input
        )
    }

    public func resolve(
        _ input: TerminalKey
    ) -> TerminalKeyResolution<Action>? {
        guard let binding = bindings[input] else {
            return nil
        }

        switch binding {
        case .key(let key):
            return .key(
                key
            )

        case .action(let action):
            return .action(
                action
            )

        case .consumed:
            return .consumed
        }
    }

    public func resolve(
        _ input: TerminalKeyStroke
    ) -> TerminalKeyResolution<Action>? {
        if let binding = keyStrokeBindings[input] {
            switch binding {
            case .key(let key):
                return .key(
                    key
                )

            case .action(let action):
                return .action(
                    action
                )

            case .consumed:
                return .consumed
            }
        }

        return resolve(
            input.key
        )
    }

    public func resolveOrFallback(
        _ input: TerminalKey
    ) -> TerminalKeyResolution<Action> {
        resolve(
            input
        ) ?? .key(
            input
        )
    }

    public func resolveOrFallback(
        _ input: TerminalKeyStroke
    ) -> TerminalKeyResolution<Action> {
        resolve(
            input
        ) ?? .key(
            input.key
        )
    }
}
