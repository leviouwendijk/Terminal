import Swim

public enum TerminalTextTargetKind:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case character
    case line
}

public struct TerminalResolvedTextTarget:
    Sendable,
    Codable,
    Hashable
{
    public let range: Range<Int>
    public let kind: TerminalTextTargetKind

    public init(
        range: Range<Int>,
        kind: TerminalTextTargetKind
    ) {
        self.range = range
        self.kind = kind
    }
}

public enum TerminalTextTargetResolver {
    public static func resolve(
        _ target: Swim.CommandTarget,
        for operation: Swim.Operator,
        in buffer: TerminalTextBuffer,
        pageRows rawPageRows: Int = 1
    ) -> TerminalResolvedTextTarget? {
        guard let resolved = resolve(
            target,
            in: buffer,
            pageRows: rawPageRows
        ) else {
            return nil
        }

        guard operation == .change else {
            return resolved
        }

        return adjustedForChange(
            resolved,
            target: target,
            in: buffer
        )
    }

    public static func resolve(
        _ target: Swim.CommandTarget,
        in buffer: TerminalTextBuffer,
        pageRows rawPageRows: Int = 1
    ) -> TerminalResolvedTextTarget? {
        let pageRows = max(
            1,
            rawPageRows
        )

        switch target {
        case .characters(let count):
            guard let range = characterRange(
                in: buffer,
                count: max(
                    1,
                    count
                )
            ) else {
                return nil
            }

            return TerminalResolvedTextTarget(
                range: range,
                kind: .character
            )

        case .line(let count):
            guard let range = lineRange(
                in: buffer,
                fromLineContaining: buffer.cursorOffset,
                downwardLineCount: max(
                    1,
                    count
                )
            ) else {
                return nil
            }

            return TerminalResolvedTextTarget(
                range: range,
                kind: .line
            )

        case .motion(
            let motion,
            count: let count
        ):
            return resolveMotion(
                motion,
                count: max(
                    1,
                    count
                ),
                in: buffer,
                pageRows: pageRows
            )
        }
    }

    private static func resolveMotion(
        _ motion: Swim.Motion,
        count: Int,
        in buffer: TerminalTextBuffer,
        pageRows: Int
    ) -> TerminalResolvedTextTarget? {
        switch motion {
        case .up:
            return linewiseVerticalTarget(
                direction: -1,
                count: count,
                in: buffer
            )

        case .down:
            return linewiseVerticalTarget(
                direction: 1,
                count: count,
                in: buffer
            )

        case .documentStart:
            guard let current = lineRange(
                in: buffer,
                fromLineContaining: buffer.cursorOffset,
                downwardLineCount: 1
            ) else {
                return nil
            }

            return TerminalResolvedTextTarget(
                range: 0..<current.upperBound,
                kind: .line
            )

        case .documentEnd:
            let lower = lineStart(
                in: buffer.text,
                containing: buffer.cursorOffset
            )

            guard lower < buffer.characterCount else {
                return nil
            }

            return TerminalResolvedTextTarget(
                range: lower..<buffer.characterCount,
                kind: .line
            )

        case .pageUp:
            return linewiseVerticalTarget(
                direction: -1,
                count: multipliedCount(
                    count,
                    pageRows
                ),
                in: buffer
            )

        case .pageDown:
            return linewiseVerticalTarget(
                direction: 1,
                count: multipliedCount(
                    count,
                    pageRows
                ),
                in: buffer
            )

        case .left,
             .right,
             .wordBackward,
             .wordForward,
             .wordEnd,
             .lineStart,
             .lineEnd:
            var destination = buffer
            let origin = buffer.cursorOffset

            _ = destination.move(
                motion,
                count: count,
                pageRows: pageRows
            )

            let targetOffset = destination.cursorOffset

            guard targetOffset != origin else {
                return nil
            }

            return TerminalResolvedTextTarget(
                range:
                    min(
                        origin,
                        targetOffset
                    )..<max(
                        origin,
                        targetOffset
                    ),
                kind: .character
            )
        }
    }

    private static func linewiseVerticalTarget(
        direction: Int,
        count: Int,
        in buffer: TerminalTextBuffer
    ) -> TerminalResolvedTextTarget? {
        let currentStart = lineStart(
            in: buffer.text,
            containing: buffer.cursorOffset
        )

        guard currentStart < buffer.characterCount else {
            return nil
        }

        if direction >= 0 {
            guard let range = lineRange(
                in: buffer,
                fromLineContaining: currentStart,
                downwardLineCount: count + 1
            ) else {
                return nil
            }

            return TerminalResolvedTextTarget(
                range: range,
                kind: .line
            )
        }

        let lower = lineStartMovingUp(
            in: buffer.text,
            from: currentStart,
            count: count
        )
        guard let current = lineRange(
            in: buffer,
            fromLineContaining: currentStart,
            downwardLineCount: 1
        ) else {
            return nil
        }

        return TerminalResolvedTextTarget(
            range: lower..<current.upperBound,
            kind: .line
        )
    }

    private static func characterRange(
        in buffer: TerminalTextBuffer,
        count: Int
    ) -> Range<Int>? {
        let lower = buffer.cursorOffset
        let end = lineEnd(
            in: buffer.text,
            containing: lower
        )
        let available = max(
            0,
            end - lower
        )
        let length = min(
            max(
                1,
                count
            ),
            available
        )

        guard length > 0 else {
            return nil
        }

        return lower..<(lower + length)
    }

    private static func lineRange(
        in buffer: TerminalTextBuffer,
        fromLineContaining offset: Int,
        downwardLineCount rawCount: Int
    ) -> Range<Int>? {
        let characters = Array(
            buffer.text
        )

        guard !characters.isEmpty else {
            return nil
        }

        let lower = lineStart(
            in: buffer.text,
            containing: offset
        )

        guard lower < characters.count else {
            return nil
        }

        var upper = lower
        var remaining = max(
            1,
            rawCount
        )

        while remaining > 0,
              upper < characters.count
        {
            while upper < characters.count,
                  characters[upper] != "\n"
            {
                upper += 1
            }

            if upper < characters.count,
               characters[upper] == "\n"
            {
                upper += 1
            }

            remaining -= 1
        }

        return lower..<upper
    }

    private static func lineEnd(
        in text: String,
        containing requestedOffset: Int
    ) -> Int {
        let characters = Array(
            text
        )
        var offset = min(
            max(
                0,
                requestedOffset
            ),
            characters.count
        )

        while offset < characters.count,
              characters[offset] != "\n"
        {
            offset += 1
        }

        return offset
    }

    private static func lineStart(
        in text: String,
        containing requestedOffset: Int
    ) -> Int {
        let characters = Array(
            text
        )
        var offset = min(
            max(
                0,
                requestedOffset
            ),
            characters.count
        )

        while offset > 0,
              characters[offset - 1] != "\n"
        {
            offset -= 1
        }

        return offset
    }

    private static func lineStartMovingUp(
        in text: String,
        from requestedStart: Int,
        count rawCount: Int
    ) -> Int {
        let characters = Array(
            text
        )
        var start = min(
            max(
                0,
                requestedStart
            ),
            characters.count
        )

        for _ in 0..<max(
            0,
            rawCount
        ) {
            guard start > 0 else {
                break
            }

            start = lineStart(
                in: text,
                containing: start - 1
            )
        }

        return start
    }

    private static func adjustedForChange(
        _ resolved: TerminalResolvedTextTarget,
        target: Swim.CommandTarget,
        in buffer: TerminalTextBuffer
    ) -> TerminalResolvedTextTarget {
        guard case .motion(
            .wordForward,
            count: _
        ) = target,
        buffer.cursorOffset < buffer.characterCount else {
            return resolved
        }

        let characters = Array(
            buffer.text
        )

        guard !isWhitespace(
            characters[
                buffer.cursorOffset
            ]
        ) else {
            return resolved
        }

        var upper = resolved.range.upperBound

        while upper > resolved.range.lowerBound,
              isWhitespace(
                characters[
                    upper - 1
                ]
              )
        {
            upper -= 1
        }

        guard upper > resolved.range.lowerBound else {
            return resolved
        }

        return TerminalResolvedTextTarget(
            range:
                resolved.range.lowerBound..<upper,
            kind: resolved.kind
        )
    }

    private static func isWhitespace(
        _ character: Character
    ) -> Bool {
        character == " "
            || character == "\t"
            || character == "\n"
    }

    private static func multipliedCount(
        _ lhs: Int,
        _ rhs: Int
    ) -> Int {
        let (
            value,
            overflow
        ) = lhs.multipliedReportingOverflow(
            by: rhs
        )

        return overflow
            ? Int.max
            : max(
                1,
                value
            )
    }
}
