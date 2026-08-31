public struct TerminalTextStyleSpan:
    Sendable,
    Hashable
{
    public var sourceRange: Range<Int>
    public var style: TerminalStyle

    public init(
        sourceRange: Range<Int>,
        style: TerminalStyle
    ) {
        self.sourceRange = sourceRange
        self.style = style
    }
}

public struct TerminalStyledText:
    Sendable,
    Hashable
{
    public var text: String
    public var style: TerminalStyle
    public var spans: [TerminalTextStyleSpan]

    public init(
        text: String,
        style: TerminalStyle = .none,
        spans: [TerminalTextStyleSpan] = []
    ) {
        self.text = text
        self.style = style
        self.spans = spans
    }

    public func renderedRows(
        columns: Int,
        tabWidth: Int = 4
    ) -> [String] {
        let sourceCount = text.count
        let layout = TerminalTextLayout(
            text: text,
            columns: columns,
            tabWidth: tabWidth
        )
        let spans = clippedSpans(
            sourceCount: sourceCount
        )

        return layout.rows.map { row in
            rendered(
                row,
                spans: spans
            )
        }
    }

    private func clippedSpans(
        sourceCount: Int
    ) -> [TerminalTextStyleSpan] {
        spans.compactMap { span in
            let lowerBound = min(
                sourceCount,
                max(
                    0,
                    span.sourceRange.lowerBound
                )
            )
            let upperBound = min(
                sourceCount,
                max(
                    lowerBound,
                    span.sourceRange.upperBound
                )
            )

            guard lowerBound < upperBound else {
                return nil
            }

            return TerminalTextStyleSpan(
                sourceRange: lowerBound..<upperBound,
                style: span.style
            )
        }
    }

    private func rendered(
        _ row: TerminalTextLayoutRow,
        spans: [TerminalTextStyleSpan]
    ) -> String {
        guard !row.content.isEmpty else {
            return row.content
        }

        var boundaries = [
            row.sourceRange.lowerBound,
            row.sourceRange.upperBound,
        ]

        for span in spans where
            span.sourceRange.overlaps(
                row.sourceRange
            )
        {
            boundaries.append(
                max(
                    row.sourceRange.lowerBound,
                    span.sourceRange.lowerBound
                )
            )
            boundaries.append(
                min(
                    row.sourceRange.upperBound,
                    span.sourceRange.upperBound
                )
            )
        }

        let orderedBoundaries = Array(
            Set(
                boundaries
            )
        ).sorted()

        return zip(
            orderedBoundaries,
            orderedBoundaries.dropFirst()
        ).map { lowerBound, upperBound in
            rendered(
                sourceRange: lowerBound..<upperBound,
                row: row,
                spans: spans
            )
        }.joined()
    }

    private func rendered(
        sourceRange: Range<Int>,
        row: TerminalTextLayoutRow,
        spans: [TerminalTextStyleSpan]
    ) -> String {
        let lowerColumn = row.column(
            atSourceOffset: sourceRange.lowerBound
        )
        let upperColumn = row.column(
            atSourceOffset: sourceRange.upperBound
        )
        let content = TerminalDisplay.slice(
            row.content,
            columns: lowerColumn..<upperColumn
        )

        guard !content.isEmpty else {
            return content
        }

        var codes = style.codes

        for span in spans where
            span.sourceRange.overlaps(
                sourceRange
            )
        {
            codes.append(
                contentsOf: span.style.codes
            )
        }

        return TerminalStyle(
            codes: codes
        ).apply(
            content
        )
    }
}
