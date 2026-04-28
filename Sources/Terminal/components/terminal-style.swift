import ANSI

public struct TerminalStyle: Sendable, Hashable {
    public var codes: [ANSIColor]

    public init(
        _ codes: ANSIColor...
    ) {
        self.codes = codes
    }

    public init(
        codes: [ANSIColor]
    ) {
        self.codes = codes
    }

    public func apply(
        _ text: String
    ) -> String {
        guard !codes.isEmpty else {
            return text
        }

        let prefix = codes
            .map(\.rawValue)
            .joined()

        return "\(prefix)\(text)\(ANSIColor.reset.rawValue)"
    }

    public static let none = TerminalStyle()
    public static let bold = TerminalStyle(.bold)
    public static let dim = TerminalStyle(.dim)
}
