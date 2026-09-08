public extension TerminalTextBuffer {
    @discardableResult
    mutating func move(
        _ motion: TerminalMotion,
        count rawCount: Int = 1,
        pageRows rawPageRows: Int = 1
    ) -> Bool {
        let count = min(
            max(
                1,
                rawCount
            ),
            max(
                1,
                characterCount + 1
            )
        )
        let pageRows = max(
            1,
            rawPageRows
        )

        switch motion {
        case .left:
            return moveLeft(
                by: count
            )

        case .right:
            return moveRight(
                by: count
            )

        case .up:
            return moveUp(
                by: count
            )

        case .down:
            return moveDown(
                by: count
            )

        case .wordBackward:
            var changed = false

            for _ in 0..<count {
                changed = moveWordBackward() || changed
            }

            return changed

        case .wordForward:
            var changed = false

            for _ in 0..<count {
                changed = moveWordForward() || changed
            }

            return changed

        case .wordEnd:
            var changed = false

            for _ in 0..<count {
                changed = moveToWordEnd() || changed
            }

            return changed

        case .lineStart:
            return moveToLineStart()

        case .lineEnd:
            var changed = false

            if count > 1 {
                changed = moveDown(
                    by: count - 1
                ) || changed
            }

            return moveToLineEnd()
                || changed

        case .documentStart:
            return moveToDocumentStart()

        case .documentEnd:
            return moveToDocumentEnd()

        case .pageUp:
            return moveUp(
                by: multipliedCount(
                    count,
                    pageRows
                )
            )

        case .pageDown:
            return moveDown(
                by: multipliedCount(
                    count,
                    pageRows
                )
            )
        }
    }

    private func multipliedCount(
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
