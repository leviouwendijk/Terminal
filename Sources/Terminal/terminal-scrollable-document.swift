public enum TerminalDocumentWrapping:
    Sendable,
    Hashable
{
    case display
    case word
}

public struct TerminalScrollableDocument:
    Sendable,
    Hashable
{
    public private(set) var lines: [String]
    public private(set) var viewport: TerminalViewport
    public private(set) var isFollowingEnd: Bool
    public private(set) var selection: TerminalTextSelection?

    private var presentationState: PresentationState?
    private var isSelecting = false
    private var mouseAnchor: TerminalTextPosition?

    public init(
        lines: [String] = [],
        visibleRows: Int = 0,
        followEnd: Bool = false
    ) {
        self.lines = lines
        self.viewport = TerminalViewport(
            contentRows: lines.count,
            visibleRows: visibleRows
        )
        self.isFollowingEnd = followEnd
        self.presentationState = nil
        self.selection = nil

        if followEnd {
            viewport.moveToEnd()
        }
    }

    public static func == (
        lhs: TerminalScrollableDocument,
        rhs: TerminalScrollableDocument
    ) -> Bool {
        lhs.lines == rhs.lines
            && lhs.viewport == rhs.viewport
            && lhs.isFollowingEnd == rhs.isFollowingEnd
            && lhs.selection == rhs.selection
    }

    public func hash(
        into hasher: inout Hasher
    ) {
        hasher.combine(
            lines
        )
        hasher.combine(
            viewport
        )
        hasher.combine(
            isFollowingEnd
        )
        hasher.combine(selection)
    }

    public var visibleLines: [String] {
        viewport.visibleRange.map {
            lines[$0]
        }
    }

    public mutating func update(
        lines: [String],
        visibleRows: Int
    ) {
        if let selection {
            let rows = selection.start.row...selection.end.row
            if rows.contains(where: { row in
                !self.lines.indices.contains(row)
                    || !lines.indices.contains(row)
                    || Self.copyLine(self.lines[row]) != Self.copyLine(lines[row])
            }) {
                clearSelection()
            }
        }
        self.lines = lines

        viewport.update(
            contentRows: lines.count,
            visibleRows: visibleRows
        )

        if isFollowingEnd {
            viewport.moveToEnd()
        }
    }

    public mutating func update(
        text: String,
        columns: Int,
        visibleRows: Int,
        wrapping: TerminalDocumentWrapping = .display
    ) {
        let columns = max(
            1,
            columns
        )
        let lines: [String]

        switch wrapping {
        case .display:
            lines = Self.displayLines(
                text,
                columns: columns
            )

        case .word:
            lines = TerminalTextWrap.lines(
                text,
                width: columns
            )
        }

        update(
            lines: lines,
            visibleRows: visibleRows
        )
    }

    private static func displayLines(
        _ text: String,
        columns: Int
    ) -> [String] {
        text.split(
            separator: "\n",
            omittingEmptySubsequences: false
        ).flatMap { rawLine -> [String] in
            let line = String(
                rawLine
            )
            let width = TerminalDisplay.width(
                of: line
            )

            guard width > 0 else {
                return [
                    line,
                ]
            }

            var lowerBound = 0
            var lines: [String] = []

            while lowerBound < width {
                let upperBound = min(
                    width,
                    lowerBound + columns
                )

                lines.append(
                    TerminalDisplay.slice(
                        line,
                        columns: lowerBound..<upperBound
                    )
                )
                lowerBound = upperBound
            }

            return lines
        }
    }

    @discardableResult
    public mutating func scrollUp(
        by rows: Int = 1
    ) -> Bool {
        let previousOffset = viewport.offset
        isFollowingEnd = false
        viewport.scrollUp(
            by: rows
        )

        return viewport.offset != previousOffset
    }

    @discardableResult
    public mutating func scrollDown(
        by rows: Int = 1
    ) -> Bool {
        let previousOffset = viewport.offset
        viewport.scrollDown(
            by: rows
        )
        isFollowingEnd = viewport.isAtEnd

        return viewport.offset != previousOffset
    }

    @discardableResult
    public mutating func pageUp(
        overlapRows: Int = 1
    ) -> Bool {
        let previousOffset = viewport.offset
        isFollowingEnd = false
        viewport.pageUp(
            overlapRows: overlapRows
        )

        return viewport.offset != previousOffset
    }

    @discardableResult
    public mutating func pageDown(
        overlapRows: Int = 1
    ) -> Bool {
        let previousOffset = viewport.offset
        viewport.pageDown(
            overlapRows: overlapRows
        )
        isFollowingEnd = viewport.isAtEnd

        return viewport.offset != previousOffset
    }

    public mutating func moveToStart() {
        isFollowingEnd = false
        viewport.moveToStart()
    }

    public mutating func moveToEnd() {
        viewport.moveToEnd()
        isFollowingEnd = true
    }

    public mutating func reveal(
        row: Int,
        margin: Int = 0
    ) {
        isFollowingEnd = false
        viewport.reveal(
            row: row,
            margin: margin
        )
    }

    public mutating func render(
        into frame: inout TerminalFrame,
        in region: TerminalRegion,
        zIndex: TerminalZIndex = .base
    ) {
        if let presentationState,
           presentationState.region == region {
            frame.scrollRows(
                in: region,
                by:
                    viewport.offset
                    - presentationState.offset
            )
        }

        presentationState = PresentationState(
            region: region,
            offset: viewport.offset
        )

        frame.write(
            viewport.visibleRange.map { selectedLine(at: $0) },
            in: region,
            zIndex: zIndex
        )
    }

    private struct PresentationState:
        Sendable
    {
        var region: TerminalRegion
        var offset: Int
    }
}

/// A character selection expressed in display cells, with an exclusive end.
public struct TerminalTextSelection: Sendable, Hashable {
    public var anchor: TerminalTextPosition
    public var head: TerminalTextPosition

    public init(anchor: TerminalTextPosition, head: TerminalTextPosition) {
        self.anchor = anchor
        self.head = head
    }

    private var isForward: Bool {
        anchor.row < head.row || (anchor.row == head.row && anchor.column <= head.column)
    }

    public var start: TerminalTextPosition { isForward ? anchor : head }
    public var end: TerminalTextPosition { isForward ? head : anchor }
}

extension TerminalScrollableDocument {
    /// Plain text from the current viewport, without terminal styling or padding.
    public var visibleText: String {
        visibleLines.map(Self.copyLine).joined(separator: "\n")
    }

    public var selectedText: String? {
        guard let selection, selection.start != selection.end,
              lines.indices.contains(selection.start.row),
              lines.indices.contains(selection.end.row) else { return nil }
        return (selection.start.row...selection.end.row).map { row in
            let line = stripANSI(lines[row])
            let lower = row == selection.start.row ? selection.start.column : 0
            let upper = row == selection.end.row
                ? selection.end.column : TerminalDisplay.width(of: line)
            return Self.copyLine(TerminalDisplay.slice(
                line, columns: Self.characterColumns(in: line, overlapping: lower..<max(lower, upper))
            ))
        }.joined(separator: "\n")
    }

    public mutating func clearSelection() {
        selection = nil
        isSelecting = false
        mouseAnchor = nil
    }

    /// Handles wheel and primary-button selection within the last rendered region.
    /// A drag past the top or bottom scrolls one row and extends the selection.
    @discardableResult
    public mutating func handle(_ mouse: TerminalMouseEvent) -> Bool {
        guard let region = presentationState?.region, !region.isEmpty else { return false }
        let inside = (region.top..<region.bottom).contains(mouse.position.row)
            && (region.leading..<region.trailing).contains(mouse.position.column)
        switch mouse.kind {
        case .scrollUp, .scrollDown:
            guard inside else { return false }
            if mouse.kind == .scrollUp { scrollUp() } else { scrollDown() }
            return true
        case .press:
            guard inside, mouse.button == 0 else { return false }
            let position = documentPosition(mouse.position, in: region)
            selection = TerminalTextSelection(anchor: position, head: position)
            mouseAnchor = position
            isSelecting = true
            // Hold the viewport steady while streamed content arrives.
            isFollowingEnd = false
            return true
        case .drag, .release:
            guard isSelecting, mouse.button == 0 else { return false }
            if mouse.kind == .drag {
                if mouse.position.row < region.top { scrollUp() }
                if mouse.position.row >= region.bottom { scrollDown() }
            }
            var position = documentPosition(mouse.position, in: region)
            if var anchor = mouseAnchor {
                // Include both endpoint cells, regardless of drag direction.
                if position.row > anchor.row
                    || (position.row == anchor.row && position.column > anchor.column) {
                    position.column += 1
                } else if position != anchor {
                    anchor.column += 1
                }
                selection = TerminalTextSelection(anchor: anchor, head: position)
            }
            if mouse.kind == .release {
                isSelecting = false
                mouseAnchor = nil
            }
            return true
        }
    }

    private func documentPosition(
        _ position: TerminalTextPosition, in region: TerminalRegion
    ) -> TerminalTextPosition {
        let row = min(max(0, lines.count - 1), viewport.offset
            + min(region.rows - 1, max(0, position.row - region.top)))
        let column = min(region.columns, max(0, position.column - region.leading))
        return TerminalTextPosition(row: row, column: column)
    }

    private static func copyLine(_ line: String) -> String {
        var text = stripANSI(line)
        while text.last == " " { text.removeLast() }
        return text
    }

    private static func characterColumns(in line: String, overlapping range: Range<Int>) -> Range<Int> {
        guard !range.isEmpty else { return range }
        var lower = range.lowerBound
        var upper = range.upperBound
        var column = 0
        for character in line {
            let end = column + TerminalDisplay.width(of: String(character))
            if column < range.upperBound && end > range.lowerBound {
                lower = min(lower, column)
                upper = max(upper, end)
            }
            column = end
            if column >= range.upperBound { break }
        }
        return lower..<upper
    }

    private func selectedLine(at row: Int) -> String {
        guard let selection, selection.start != selection.end,
              (selection.start.row...selection.end.row).contains(row) else { return lines[row] }
        let line = stripANSI(lines[row])
        let width = TerminalDisplay.width(of: line)
        let start = min(width, row == selection.start.row ? selection.start.column : 0)
        let end = min(width, row == selection.end.row ? selection.end.column : width)
        guard start < end else { return lines[row] }
        let columns = Self.characterColumns(in: line, overlapping: start..<end)
        let lower = columns.lowerBound
        let upper = columns.upperBound
        return TerminalDisplay.slice(line, columns: 0..<lower)
            + TerminalStyle(.inverse).apply(TerminalDisplay.slice(line, columns: lower..<upper))
            + TerminalDisplay.slice(line, columns: upper..<width)
    }
}
