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
    }

    static func run() throws {
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
}
