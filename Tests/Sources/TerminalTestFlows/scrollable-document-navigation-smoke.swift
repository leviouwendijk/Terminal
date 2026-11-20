import Terminal

enum TerminalScrollableDocumentNavigationSmoke {
    enum Failure:
        Error
    {
        case initialFollow
        case scrollUp
        case scrollDown
        case pageUp
        case pageDown
        case boundaries
        case mouseSelection
    }

    static func run() throws {
        try mouseSelection()
        var document = TerminalScrollableDocument(
            lines: (0..<20).map(String.init),
            visibleRows: 5,
            followEnd: true
        )

        guard document.viewport.offset == 15,
              document.viewport.isAtEnd,
              document.isFollowingEnd else {
            throw Failure.initialFollow
        }

        guard document.scrollUp(),
              document.viewport.offset == 14,
              !document.isFollowingEnd else {
            throw Failure.scrollUp
        }

        guard document.scrollDown(),
              document.viewport.offset == 15,
              document.viewport.isAtEnd,
              document.isFollowingEnd else {
            throw Failure.scrollDown
        }

        guard document.pageUp(),
              document.viewport.offset == 11,
              !document.isFollowingEnd else {
            throw Failure.pageUp
        }

        guard document.pageDown(),
              document.viewport.offset == 15,
              document.viewport.isAtEnd,
              document.isFollowingEnd else {
            throw Failure.pageDown
        }

        document.moveToStart()

        guard document.viewport.offset == 0,
              document.viewport.isAtStart,
              !document.isFollowingEnd,
              !document.scrollUp(),
              document.viewport.offset == 0,
              !document.isFollowingEnd else {
            throw Failure.boundaries
        }

        document.moveToEnd()

        guard document.viewport.offset == 15,
              document.isFollowingEnd,
              !document.scrollDown(),
              document.viewport.offset == 15,
              document.isFollowingEnd else {
            throw Failure.boundaries
        }
    }

    private static func mouseSelection() throws {
        let lines = [TerminalStyle.bold.apply("hello 你🙂 world"), "second line", "third", "fourth"]
        var document = TerminalScrollableDocument(lines: lines, visibleRows: 2)
        let region = TerminalRegion(top: 2, leading: 3, rows: 2, columns: 20)
        var frame = TerminalFrame(rows: 10, columns: 30)
        document.render(into: &frame, in: region)

        guard !document.handle(.init(kind: .scrollDown, row: 0, column: 0)),
              document.viewport.offset == 0,
              document.handle(.init(kind: .press, row: 2, column: 9)),
              document.handle(.init(kind: .drag, row: 2, column: 12)),
              document.handle(.init(kind: .release, row: 2, column: 12)),
              document.selectedText == "你🙂",
              !document.isFollowingEnd,
              document.visibleText == "hello 你🙂 world\nsecond line" else {
            throw Failure.mouseSelection
        }
        document.clearSelection()
        document.handle(.init(kind: .press, row: 2, column: 12))
        document.handle(.init(kind: .drag, row: 2, column: 9))
        document.handle(.init(kind: .release, row: 2, column: 9))
        guard document.selectedText == "你🙂" else { throw Failure.mouseSelection }
        document.clearSelection()
        // Multiline selection remains anchored in document coordinates while scrolling.
        document.handle(.init(kind: .press, row: 2, column: 3))
        document.handle(.init(kind: .drag, row: 3, column: 8))
        document.handle(.init(kind: .release, row: 3, column: 8))
        guard document.selectedText == "hello 你🙂 world\nsecond" else {
            throw Failure.mouseSelection
        }
        document.handle(.init(kind: .scrollDown, row: 2, column: 3))
        guard document.viewport.offset == 1,
              document.selectedText == "hello 你🙂 world\nsecond" else {
            throw Failure.mouseSelection
        }
        document.update(lines: lines + ["fifth"], visibleRows: 2)
        guard document.viewport.offset == 1, document.selectedText != nil else {
            throw Failure.mouseSelection
        }
        document.handle(.init(kind: .scrollDown, row: 2, column: 3))
        document.handle(.init(kind: .scrollDown, row: 2, column: 3))
        guard document.viewport.offset == 3, document.isFollowingEnd else {
            throw Failure.mouseSelection
        }
        document.update(lines: lines + ["fifth", "sixth"], visibleRows: 2)
        guard document.viewport.offset == 4 else { throw Failure.mouseSelection }
        document.update(lines: ["replacement"], visibleRows: 2)
        guard document.selectedText == nil else { throw Failure.mouseSelection }
    }
}
