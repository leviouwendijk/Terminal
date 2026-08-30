public struct TerminalZIndex:
    Sendable,
    Codable,
    Hashable,
    Comparable
{
    public var rawValue: Int

    public init(
        _ rawValue: Int
    ) {
        self.rawValue = rawValue
    }

    public static func < (
        lhs: TerminalZIndex,
        rhs: TerminalZIndex
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public static let base = TerminalZIndex(
        0
    )

    public static let overlay = TerminalZIndex(
        100
    )
}

public struct TerminalFrameSpan:
    Sendable,
    Hashable
{
    public var row: Int
    public var leading: Int
    public var columns: Int
    public var content: String
    public var zIndex: TerminalZIndex

    public init(
        row: Int,
        leading: Int,
        columns: Int,
        content: String,
        zIndex: TerminalZIndex = .base
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
        self.zIndex = zIndex
    }
}

public struct TerminalFrameScroll:
    Sendable,
    Hashable
{
    public var top: Int
    public var rows: Int
    public var delta: Int

    public init(
        top: Int,
        rows: Int,
        delta: Int
    ) {
        self.top = max(
            0,
            top
        )
        self.rows = max(
            0,
            rows
        )
        self.delta = delta
    }

    public var bottom: Int {
        top + rows
    }

    public var rowRange: Range<Int> {
        top..<bottom
    }
}

public struct TerminalFrameCursor:
    Sendable,
    Hashable
{
    public var row: Int
    public var column: Int
    public var shape: TerminalCursorShape

    public init(
        row: Int,
        column: Int,
        shape: TerminalCursorShape = .automatic
    ) {
        self.row = max(
            0,
            row
        )
        self.column = max(
            0,
            column
        )
        self.shape = shape
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
    public private(set) var scrolls: [TerminalFrameScroll]

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
        self.scrolls = []
    }

    public mutating func write(
        _ text: String,
        in region: TerminalRegion,
        zIndex: TerminalZIndex = .base
    ) {
        write(
            text.split(
                separator: "\n",
                omittingEmptySubsequences: false
            ).map(
                String.init
            ),
            in: region,
            zIndex: zIndex
        )
    }

    public mutating func write(
        _ lines: [String],
        in region: TerminalRegion,
        zIndex: TerminalZIndex = .base
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
                        : "",
                    zIndex: zIndex
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

    public mutating func scrollRows(
        in region: TerminalRegion,
        by delta: Int
    ) {
        let top = min(
            rows,
            max(
                0,
                region.top
            )
        )
        let bottom = min(
            rows,
            max(
                top,
                region.bottom
            )
        )
        let visibleRows = bottom - top

        guard delta != 0,
              visibleRows > 1,
              abs(delta) < visibleRows else {
            return
        }

        let scroll = TerminalFrameScroll(
            top: top,
            rows: visibleRows,
            delta: delta
        )

        guard !scrolls.contains(
            where: {
                $0.rowRange.overlaps(
                    scroll.rowRange
                )
            }
        ) else {
            return
        }

        scrolls.append(
            scroll
        )
    }

    public mutating func placeCursor(
        row: Int,
        column: Int,
        shape: TerminalCursorShape = .automatic
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
            ),
            shape: shape
        )
    }

    public mutating func clearCursor() {
        cursor = nil
    }

    public mutating func removeAll() {
        spans.removeAll(
            keepingCapacity: true
        )
        scrolls.removeAll(
            keepingCapacity: true
        )
        cursor = nil
    }
}
