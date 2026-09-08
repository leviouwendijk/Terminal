public enum TerminalRegisterValue:
    Sendable,
    Codable,
    Hashable
{
    case character(String)
    case line(String)
    case block([String])

    public var kind: TerminalSelectionKind {
        switch self {
        case .character:
            return .character

        case .line:
            return .line

        case .block:
            return .block
        }
    }

    public var text: String {
        switch self {
        case .character(let text),
             .line(let text):
            return text

        case .block(let rows):
            return rows.joined(
                separator: "\n"
            )
        }
    }

    public init?(
        capturing target: TerminalResolvedTextTarget,
        in buffer: TerminalTextBuffer
    ) {
        let text = buffer.text(
            in: target.range
        )

        switch target.kind {
        case .character:
            self = .character(
                text
            )

        case .line:
            self = .line(
                text
            )
        }
    }

    public init?(
        capturing selection: TerminalResolvedSelection,
        in buffer: TerminalTextBuffer
    ) {
        switch selection {
        case .contiguous(
            let range,
            let kind
        ):
            let text = buffer.text(
                in: range
            )

            switch kind {
            case .character:
                self = .character(
                    text
                )

            case .line:
                self = .line(
                    text
                )

            case .block:
                return nil
            }

        case .block(let block):
            self = .block(
                block.rows.map { row in
                    guard let range = row.sourceRange else {
                        return ""
                    }

                    return buffer.text(
                        in: range
                    )
                }
            )
        }
    }
}

public struct TerminalRegisterBank:
    Sendable,
    Codable,
    Hashable
{
    public private(set) var unnamed: TerminalRegisterValue?

    public init(
        unnamed: TerminalRegisterValue? = nil
    ) {
        self.unnamed = unnamed
    }

    public mutating func writeUnnamed(
        _ value: TerminalRegisterValue
    ) {
        unnamed = value
    }

    public mutating func clearUnnamed() {
        unnamed = nil
    }
}
