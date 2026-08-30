public struct TerminalScrollableDocument:
    Sendable,
    Hashable
{
    public private(set) var lines: [String]
    public private(set) var viewport: TerminalViewport
    public private(set) var isFollowingEnd: Bool

    private var presentationState: PresentationState?

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
        self.lines = lines

        viewport.update(
            contentRows: lines.count,
            visibleRows: visibleRows
        )

        if isFollowingEnd {
            viewport.moveToEnd()
        }
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

    @discardableResult
    public mutating func handle(
        _ action: TerminalInteractionAction
    ) -> Bool {
        guard case .motion(let motion) = action else {
            return false
        }

        switch motion {
        case .up:
            isFollowingEnd = false
            viewport.scrollUp()
            return true

        case .down:
            viewport.scrollDown()
            isFollowingEnd = viewport.isAtEnd
            return true

        case .pageUp:
            isFollowingEnd = false
            viewport.pageUp()
            return true

        case .pageDown:
            viewport.pageDown()
            isFollowingEnd = viewport.isAtEnd
            return true

        case .documentStart:
            moveToStart()
            return true

        case .documentEnd:
            moveToEnd()
            return true

        case .left,
             .right,
             .wordBackward,
             .wordForward,
             .wordEnd,
             .lineStart,
             .lineEnd:
            return false
        }
    }

    public mutating func render(
        into frame: inout TerminalFrame,
        in region: TerminalRegion
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
            visibleLines,
            in: region
        )
    }

    private struct PresentationState:
        Sendable
    {
        var region: TerminalRegion
        var offset: Int
    }
}
