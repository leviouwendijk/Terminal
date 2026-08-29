public struct TerminalFrameSpan:
    Sendable,
    Hashable
{
    public var row: Int
    public var leading: Int
    public var columns: Int
    public var content: String

    public init(
        row: Int,
        leading: Int,
        columns: Int,
        content: String
    ) {
        self.row = max(
            0,
            row
        )
        self.leading = max(
            0,
            leading
        )
        self.columns = max(
            0,
            columns
        )
        self.content = content
    }
}

public struct TerminalFrameCursor:
    Sendable,
    Hashable
{
    public var row: Int
    public var column: Int

    public init(
        row: Int,
        column: Int
    ) {
        self.row = max(
            0,
            row
        )
        self.column = max(
            0,
            column
        )
    }
}

public struct TerminalFrame:
    Sendable,
    Hashable
{
    public var rows: Int
    public var columns: Int
    public private(set) var spans: [TerminalFrameSpan]
    public private(set) var cursor: TerminalFrameCursor?

    public init(
        rows: Int,
        columns: Int
    ) {
        self.rows = max(
            0,
            rows
        )
        self.columns = max(
            0,
            columns
        )
        self.spans = []
        self.cursor = nil
    }

    public mutating func write(
        _ text: String,
        in region: TerminalRegion
    ) {
        write(
            text.split(
                separator: "\n",
                omittingEmptySubsequences: false
            ).map(
                String.init
            ),
            in: region
        )
    }

    public mutating func write(
        _ lines: [String],
        in region: TerminalRegion
    ) {
        guard region.top < rows,
              region.leading < columns,
              region.rows > 0,
              region.columns > 0 else {
            return
        }

        let visibleRows = min(
            region.rows,
            rows - region.top
        )
        let visibleColumns = min(
            region.columns,
            columns - region.leading
        )

        guard visibleRows > 0,
              visibleColumns > 0 else {
            return
        }

        for index in 0..<visibleRows {
            spans.append(
                TerminalFrameSpan(
                    row: region.top + index,
                    leading: region.leading,
                    columns: visibleColumns,
                    content:
                        index < lines.count
                        ? lines[index]
                        : ""
                )
            )
        }
    }

    public func spans(
        inRow row: Int
    ) -> [TerminalFrameSpan] {
        spans.filter {
            $0.row == row
        }
    }

    public mutating func placeCursor(
        row: Int,
        column: Int
    ) {
        cursor = TerminalFrameCursor(
            row: min(
                max(
                    0,
                    row
                ),
                max(
                    0,
                    rows - 1
                )
            ),
            column: min(
                max(
                    0,
                    column
                ),
                max(
                    0,
                    columns - 1
                )
            )
        )
    }

    public mutating func clearCursor() {
        cursor = nil
    }

    public mutating func removeAll() {
        spans.removeAll(
            keepingCapacity: true
        )
        cursor = nil
    }
}
