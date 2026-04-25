import Foundation

public struct TerminalLineChoice: Sendable, Codable, Hashable {
    public var key: String
    public var title: String
    public var detail: String?

    public init(
        key: String,
        title: String,
        detail: String? = nil
    ) {
        self.key = key
        self.title = title
        self.detail = detail
    }
}

public extension Terminal {
    static func promptLine(
        _ prompt: String,
        default defaultValue: String? = nil,
        stream: TerminalStream = .standardOutput
    ) -> String? {
        if let defaultValue,
           !defaultValue.isEmpty {
            write(
                "\(prompt) [\(defaultValue)] ",
                to: stream
            )
        } else {
            write(
                "\(prompt) ",
                to: stream
            )
        }

        flush(
            stream
        )

        let raw = readLine()?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard let raw,
              !raw.isEmpty else {
            return defaultValue
        }

        return raw
    }

    static func chooseLine(
        _ prompt: String,
        choices: [TerminalLineChoice],
        default defaultKey: String? = nil,
        stream: TerminalStream = .standardOutput
    ) -> TerminalLineChoice? {
        guard !choices.isEmpty else {
            return nil
        }

        write(
            prompt + "\n",
            to: stream
        )

        for choice in choices {
            var line = "  [\(choice.key)] \(choice.title)"

            if let detail = choice.detail,
               !detail.isEmpty {
                line += " — \(detail)"
            }

            write(
                line + "\n",
                to: stream
            )
        }

        let suffix: String

        if let defaultKey,
           !defaultKey.isEmpty {
            suffix = "> [\(defaultKey)] "
        } else {
            suffix = "> "
        }

        write(
            suffix,
            to: stream
        )
        flush(
            stream
        )

        let raw = readLine()?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let key = (raw?.isEmpty == false)
            ? raw!
            : defaultKey

        guard let key else {
            return nil
        }

        return choices.first {
            $0.key.caseInsensitiveCompare(key) == .orderedSame
        }
    }
}
