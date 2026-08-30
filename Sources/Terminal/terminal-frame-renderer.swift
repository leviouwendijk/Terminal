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
        var comparisonFrame = previousFrame
        var output: [String] = []

        if requiresFullRender {
            output.append(
                ANSIColor.clearScreen.rawValue
            )
        } else if var scrolledFrame = previousFrame {
            for scroll in frame.scrolls {
                output.append(
                    scrollSequence(
                        scroll
                    )
                )
                scrolledFrame = applying(
                    scroll,
                    to: scrolledFrame
                )
            }

            comparisonFrame = scrolledFrame
        }

        let rows = rowsToRender(
            resolvedFrame,
            previousFrame: comparisonFrame,
            requiresFullRender: requiresFullRender
        )

        if !requiresFullRender,
           !frame.scrolls.isEmpty,
           let comparisonFrame {
            output.append(
                contentsOf: rows.map {
                    renderChangedRow(
                        $0,
                        frame: resolvedFrame,
                        previousFrame: comparisonFrame
                    )
                }
            )
        } else {
            output.append(
                contentsOf: rows.map {
                    renderRow(
                        $0,
                        frame: resolvedFrame
                    )
                }
            )
        }
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

        return cursor.shape.escapeSequence
            + cursorPosition(
                line: cursor.row + 1,
                column: cursor.column + 1
            )
            + "\u{001B}[?25h"
    }

    private func rowsToRender(
        _ frame: TerminalResolvedFrame,
        previousFrame: TerminalResolvedFrame?,
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

    private func applying(
        _ scroll: TerminalFrameScroll,
        to frame: TerminalResolvedFrame
    ) -> TerminalResolvedFrame {
        let range = scroll.rowRange
        var spans: [TerminalFrameSpan] = []

        spans.reserveCapacity(
            frame.spans.count
        )

        for span in frame.spans {
            guard range.contains(
                span.row
            ) else {
                spans.append(
                    span
                )
                continue
            }

            let row = span.row - scroll.delta

            guard range.contains(
                row
            ) else {
                continue
            }

            var shifted = span
            shifted.row = row
            spans.append(
                shifted
            )
        }

        return TerminalResolvedFrame(
            rows: frame.rows,
            columns: frame.columns,
            spans: spans,
            cursor: frame.cursor
        )
    }

    private func scrollSequence(
        _ scroll: TerminalFrameScroll
    ) -> String {
        let amount = abs(
            scroll.delta
        )
        let command = scroll.delta > 0
            ? "S"
            : "T"

        return "\u{001B}[\(scroll.top + 1);\(scroll.bottom)r"
            + "\u{001B}[\(amount)\(command)"
            + "\u{001B}[r"
    }

    private func renderChangedRow(
        _ row: Int,
        frame: TerminalResolvedFrame,
        previousFrame: TerminalResolvedFrame
    ) -> String {
        let previousSpans = previousFrame.spans(
            inRow: row
        )
        let spans = frame.spans(
            inRow: row
        )

        guard previousSpans.count == spans.count,
              zip(
                previousSpans,
                spans
              ).allSatisfy({
                previous,
                current in

                previous.leading == current.leading
                    && previous.columns == current.columns
              }) else {
            return renderRow(
                row,
                frame: frame
            )
        }

        var output = [
            ANSIColor.reset.rawValue,
        ]

        for (
            previous,
            span
        ) in zip(
            previousSpans,
            spans
        ) where previous.content != span.content {
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

        var column = 0

        for span in frame.spans(
            inRow: row
        ) {
            if span.leading != column {
                output.append(
                    cursorPosition(
                        line: row + 1,
                        column: span.leading + 1
                    )
                )
            }

            output.append(
                span.content
            )
            column = span.leading + span.columns
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
