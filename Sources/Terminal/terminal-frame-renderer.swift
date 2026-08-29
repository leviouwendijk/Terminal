public struct TerminalFrameRenderer:
    Sendable
{
    public var stream: TerminalStream

    private var previousFrame: TerminalFrame?

    public init(
        stream: TerminalStream = .standardError
    ) {
        self.stream = stream
        self.previousFrame = nil
    }

    public mutating func render(
        _ frame: TerminalFrame
    ) {
        let requiresFullRender = previousFrame.map {
            previous in

            previous.rows != frame.rows
                || previous.columns != frame.columns
        } ?? true

        if requiresFullRender {
            Terminal.clearScreen(
                to: stream
            )
        }

        let rows = rowsToRender(
            frame,
            requiresFullRender: requiresFullRender
        )

        for row in rows {
            renderRow(
                row,
                frame: frame
            )
        }

        renderCursor(
            frame.cursor
        )

        Terminal.flush(
            stream
        )

        previousFrame = frame
    }

    public mutating func invalidate() {
        previousFrame = nil
    }

    private func renderCursor(
        _ cursor: TerminalFrameCursor?
    ) {
        guard let cursor else {
            Terminal.hideCursor(
                on: stream
            )
            return
        }

        Terminal.moveCursor(
            line: cursor.row + 1,
            column: cursor.column + 1,
            to: stream
        )
        Terminal.showCursor(
            on: stream
        )
    }

    private func rowsToRender(
        _ frame: TerminalFrame,
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
        frame: TerminalFrame
    ) {
        Terminal.moveCursor(
            line: row + 1,
            column: 1,
            to: stream
        )
        Terminal.clearLine(
            on: stream
        )

        for span in frame.spans(
            inRow: row
        ) {
            Terminal.moveCursor(
                line: row + 1,
                column: span.leading + 1,
                to: stream
            )
            Terminal.write(
                TerminalDisplay.fitted(
                    span.content,
                    columns: span.columns
                ),
                to: stream
            )
        }
    }
}
