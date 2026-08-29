public struct TerminalFrameRenderer:
    Sendable
{
    public var stream: TerminalStream

    private var previousFrame: TerminalResolvedFrame?

    public init(
        stream: TerminalStream = .standardError
    ) {
        self.stream = stream
        self.previousFrame = nil
    }

    public mutating func render(
        _ frame: TerminalFrame
    ) {
        Terminal.withOutputTransaction {
            renderFrame(
                frame
            )
        }
    }

    private mutating func renderFrame(
        _ frame: TerminalFrame
    ) {
        let resolvedFrame = frame.resolved()
        let requiresFullRender = previousFrame.map {
            previous in

            previous.rows != resolvedFrame.rows
                || previous.columns != resolvedFrame.columns
        } ?? true
        let rows = rowsToRender(
            resolvedFrame,
            requiresFullRender: requiresFullRender
        )
        var output: [String] = []

        if requiresFullRender {
            output.append(
                ANSIColor.clearScreen.rawValue
            )
        }

        output.append(
            contentsOf: rows.map {
                renderRow(
                    $0,
                    frame: resolvedFrame
                )
            }
        )
        output.append(
            cursorSequence(
                resolvedFrame.cursor
            )
        )

        Terminal.write(
            output.joined(),
            to: stream
        )
        Terminal.flush(
            stream
        )

        previousFrame = resolvedFrame
    }

    public mutating func invalidate() {
        previousFrame = nil
    }

    private func cursorSequence(
        _ cursor: TerminalFrameCursor?
    ) -> String {
        guard let cursor else {
            return "\u{001B}[?25l"
        }

        return cursorPosition(
            line: cursor.row + 1,
            column: cursor.column + 1
        )
            + "\u{001B}[?25h"
    }

    private func rowsToRender(
        _ frame: TerminalResolvedFrame,
        requiresFullRender: Bool
    ) -> [Int] {
        guard !requiresFullRender,
              let previousFrame else {
            return Array(
                0..<frame.rows
            )
        }

        return (0..<frame.rows).filter {
            row in

            previousFrame.spans(
                inRow: row
            ) != frame.spans(
                inRow: row
            )
        }
    }

    private func renderRow(
        _ row: Int,
        frame: TerminalResolvedFrame
    ) -> String {
        var output = [
            cursorPosition(
                line: row + 1,
                column: 1
            ),
            ANSIColor.reset.rawValue,
            ANSIColor.clearLine.rawValue,
        ]

        for span in frame.spans(
            inRow: row
        ) {
            output.append(
                cursorPosition(
                    line: row + 1,
                    column: span.leading + 1
                )
            )
            output.append(
                span.content
            )
        }

        return output.joined()
    }

    private func cursorPosition(
        line: Int,
        column: Int
    ) -> String {
        "\u{001B}[\(max(1, line));\(max(1, column))H"
    }
}
