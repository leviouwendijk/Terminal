/// SGR mouse input. Positions use zero-based terminal display cells.
public struct TerminalMouseEvent: Sendable, Codable, Hashable {
    public enum Kind: String, Sendable, Codable, Hashable {
        case press, drag, release, scrollUp, scrollDown
    }

    public var kind: Kind
    public var position: TerminalTextPosition
    public var modifiers: TerminalKeyModifiers
    public var button: Int

    public init(
        kind: Kind,
        row: Int,
        column: Int,
        modifiers: TerminalKeyModifiers = [],
        button: Int = 0
    ) {
        self.kind = kind
        self.position = TerminalTextPosition(row: row, column: column)
        self.modifiers = modifiers
        self.button = button
    }

    static func decode(_ bytes: [UInt8]) -> Self? {
        guard bytes.first == 0x3C,
              let final = bytes.last, final == 0x4D || final == 0x6D else {
            return nil
        }
        let fields = String(decoding: bytes.dropFirst().dropLast(), as: UTF8.self)
            .split(separator: ";", omittingEmptySubsequences: false)
        guard fields.count == 3,
              let code = Int(fields[0]), (0...127).contains(code),
              let column = Int(fields[1]), column > 0,
              let row = Int(fields[2]), row > 0 else {
            return nil
        }
        let kind: Kind
        if code & 64 != 0 {
            guard code & 3 < 2, final == 0x4D else { return nil }
            kind = code & 1 == 0 ? .scrollUp : .scrollDown
        } else if final == 0x6D {
            kind = .release
        } else {
            kind = code & 32 != 0 ? .drag : .press
        }
        var modifiers: TerminalKeyModifiers = []
        if code & 4 != 0 { modifiers.insert(.shift) }
        if code & 8 != 0 { modifiers.insert(.option) }
        if code & 16 != 0 { modifiers.insert(.control) }
        return Self(
            kind: kind, row: row - 1, column: column - 1,
            modifiers: modifiers, button: code & 3
        )
    }
}
