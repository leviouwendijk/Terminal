public struct TerminalViewport: Sendable, Codable, Hashable {
    public private(set) var contentRows: Int
    public private(set) var visibleRows: Int
    public private(set) var offset: Int

    public init(
        contentRows: Int = 0,
        visibleRows: Int,
        offset: Int = 0
    ) {
        self.contentRows = max(
            0,
            contentRows
        )
        self.visibleRows = max(
            0,
            visibleRows
        )
        self.offset = max(
            0,
            offset
        )

        normalize()
    }

    public var maximumOffset: Int {
        max(
            0,
            contentRows - visibleRows
        )
    }

    public var visibleRange: Range<Int> {
        let end = min(
            contentRows,
            offset + visibleRows
        )

        return offset..<end
    }

    public var isAtStart: Bool {
        offset == 0
    }

    public var isAtEnd: Bool {
        offset == maximumOffset
    }

    public mutating func update(
        contentRows: Int,
        visibleRows: Int
    ) {
        self.contentRows = max(
            0,
            contentRows
        )
        self.visibleRows = max(
            0,
            visibleRows
        )

        normalize()
    }

    public mutating func scroll(
        by rows: Int
    ) {
        offset += rows
        normalize()
    }

    public mutating func scrollUp(
        by rows: Int = 1
    ) {
        scroll(
            by: -max(
                1,
                rows
            )
        )
    }

    public mutating func scrollDown(
        by rows: Int = 1
    ) {
        scroll(
            by: max(
                1,
                rows
            )
        )
    }

    public mutating func pageUp(
        overlapRows: Int = 1
    ) {
        scrollUp(
            by: pageDistance(
                overlapRows: overlapRows
            )
        )
    }

    public mutating func pageDown(
        overlapRows: Int = 1
    ) {
        scrollDown(
            by: pageDistance(
                overlapRows: overlapRows
            )
        )
    }

    public mutating func moveToStart() {
        offset = 0
    }

    public mutating func moveToEnd() {
        offset = maximumOffset
    }

    public mutating func reveal(
        row: Int,
        margin: Int = 0
    ) {
        guard contentRows > 0,
              visibleRows > 0 else {
            offset = 0
            return
        }

        let row = min(
            max(
                0,
                row
            ),
            contentRows - 1
        )
        let margin = min(
            max(
                0,
                margin
            ),
            max(
                0,
                visibleRows - 1
            )
        )

        let visibleStart = offset + margin
        let visibleEnd = offset + visibleRows - 1 - margin

        if row < visibleStart {
            offset = row - margin
        } else if row > visibleEnd {
            offset = row - visibleRows + 1 + margin
        }

        normalize()
    }

    private func pageDistance(
        overlapRows: Int
    ) -> Int {
        max(
            1,
            visibleRows - max(
                0,
                overlapRows
            )
        )
    }

    private mutating func normalize() {
        offset = min(
            max(
                0,
                offset
            ),
            maximumOffset
        )
    }
}
