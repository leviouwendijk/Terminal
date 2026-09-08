public struct TerminalReplaceSession:
    Sendable,
    Codable,
    Hashable
{
    public struct Step:
        Sendable,
        Codable,
        Hashable
    {
        public let offset: Int
        public let original: String?
        public let replacement: String

        public init(
            offset: Int,
            original: String?,
            replacement: String
        ) {
            self.offset = max(
                0,
                offset
            )
            self.original = original
            self.replacement = replacement
        }
    }

    public let startOffset: Int
    public private(set) var steps: [Step]

    public init(
        startOffset: Int,
        steps: [Step] = []
    ) {
        self.startOffset = max(
            0,
            startOffset
        )
        self.steps = steps
    }

    @discardableResult
    public mutating func apply(
        _ rawReplacement: String,
        to buffer: inout TerminalTextBuffer
    ) -> Bool {
        let replacement =
            rawReplacement == "\r"
            ? "\n"
            : rawReplacement

        guard replacement.count == 1 else {
            return false
        }

        let offset = buffer.cursorOffset

        if replacement == "\n" {
            guard buffer.insertNewline() else {
                return false
            }

            steps.append(
                Step(
                    offset: offset,
                    original: nil,
                    replacement: replacement
                )
            )
            return true
        }

        if offset < buffer.characterCount {
            let next = buffer.text(
                in: offset..<(offset + 1)
            )

            if next != "\n" {
                guard buffer.replace(
                    offset..<(offset + 1),
                    with: replacement
                ) else {
                    return false
                }

                steps.append(
                    Step(
                        offset: offset,
                        original: next,
                        replacement: replacement
                    )
                )
                return true
            }
        }

        guard buffer.insert(
            replacement
        ) else {
            return false
        }

        steps.append(
            Step(
                offset: offset,
                original: nil,
                replacement: replacement
            )
        )
        return true
    }

    @discardableResult
    public mutating func restoreLast(
        in buffer: inout TerminalTextBuffer
    ) -> Bool {
        guard let step = steps.last,
              buffer.cursorOffset
                == step.offset + step.replacement.count else {
            return false
        }

        let changed: Bool
        let range = step.offset..<(step.offset + step.replacement.count)

        if let original = step.original {
            changed = buffer.replace(
                range,
                with: original
            )

            if changed {
                _ = buffer.setCursor(
                    offset: step.offset
                )
            }
        } else {
            changed = buffer.delete(
                range
            )
        }

        guard changed else {
            return false
        }

        steps.removeLast()
        return true
    }
}
