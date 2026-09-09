public struct TerminalTextDecoration:
    Sendable,
    Hashable
{
    public var sourceRanges: [Range<Int>]
    public var style: TerminalStyle

    public init(
        sourceRange: Range<Int>,
        style: TerminalStyle
    ) {
        self.init(
            sourceRanges: [
                sourceRange,
            ],
            style: style
        )
    }

    public init(
        sourceRanges: [Range<Int>],
        style: TerminalStyle
    ) {
        self.sourceRanges = sourceRanges
        self.style = style
    }

    public func contains(
        sourceOffset: Int
    ) -> Bool {
        sourceRanges.contains { range in
            range.contains(
                sourceOffset
            )
        }
    }
}

public extension TerminalTextLayoutRow {
    func renderedContent(
        decorations: [TerminalTextDecoration] = []
    ) -> String {
        guard !decorations.isEmpty,
              !sourceRange.isEmpty else {
            return content
        }

        var rendered = ""

        for sourceOffset in sourceRange {
            let lowerColumn = column(
                atSourceOffset: sourceOffset
            )
            let upperColumn = column(
                atSourceOffset: sourceOffset + 1
            )
            let segment = TerminalDisplay.slice(
                content,
                columns: lowerColumn..<upperColumn
            )
            let style = decorations.reduce(
                TerminalStyle.none
            ) { partialResult, decoration in
                guard decoration.contains(
                    sourceOffset: sourceOffset
                ) else {
                    return partialResult
                }

                return partialResult.merging(
                    decoration.style
                )
            }

            rendered += style.apply(
                segment
            )
        }

        return rendered
    }
}
