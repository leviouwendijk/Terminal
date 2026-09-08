public struct TerminalKeyModifiers:
    OptionSet,
    Sendable,
    Codable,
    Hashable
{
    public let rawValue: UInt16

    public init(
        rawValue: UInt16
    ) {
        self.rawValue = rawValue
    }

    public static let shift = Self(
        rawValue: 1 << 0
    )
    public static let option = Self(
        rawValue: 1 << 1
    )
    public static let control = Self(
        rawValue: 1 << 2
    )
    public static let command = Self(
        rawValue: 1 << 3
    )
    public static let hyper = Self(
        rawValue: 1 << 4
    )
    public static let meta = Self(
        rawValue: 1 << 5
    )
    public static let capsLock = Self(
        rawValue: 1 << 6
    )
    public static let numLock = Self(
        rawValue: 1 << 7
    )
}

public struct TerminalKeyStroke:
    Sendable,
    Codable,
    Hashable
{
    public var key: TerminalKey
    public var modifiers: TerminalKeyModifiers

    public init(
        key: TerminalKey,
        modifiers: TerminalKeyModifiers = []
    ) {
        self.key = key
        self.modifiers = modifiers
    }
}
