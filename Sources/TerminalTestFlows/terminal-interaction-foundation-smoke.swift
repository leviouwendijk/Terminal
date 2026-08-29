import Terminal

enum TerminalInteractionFoundationSmoke {
    enum Failure:
        Error
    {
        case unexpectedMode
        case unexpectedInteraction
        case unexpectedDocument
    }

    static func run() throws {
        try runModalInteractionProbe()
        try runScrollableDocumentProbe()
    }

    private static func runModalInteractionProbe() throws {
        var interaction = TerminalModalInteraction()

        guard interaction.mode == .normal,
              interaction.handle(
                .char("i")
              ) == .action(
                .enterInsert(
                    .beforeCursor
                )
              ),
              interaction.mode == .insert else {
            throw Failure.unexpectedMode
        }

        guard interaction.handle(
            .char("x")
        ) == .action(
            .literal(
                .char("x")
            )
        ) else {
            throw Failure.unexpectedInteraction
        }

        guard interaction.handle(
            .escape
        ) == .action(
            .returnToNormal
        ),
        interaction.mode == .normal else {
            throw Failure.unexpectedMode
        }

        guard interaction.handle(
            .char("v")
        ) == .action(
            .enterVisual
        ),
        interaction.mode == .visual else {
            throw Failure.unexpectedMode
        }

        guard interaction.handle(
            .char("j")
        ) == .action(
            .motion(
                .down
            )
        ) else {
            throw Failure.unexpectedInteraction
        }

        guard interaction.handle(
            .escape
        ) == .action(
            .returnToNormal
        ),
        interaction.mode == .normal else {
            throw Failure.unexpectedMode
        }

        guard interaction.handle(
            .char("g")
        ) == .consumed,
        interaction.handle(
            .char("g")
        ) == .action(
            .motion(
                .documentStart
            )
        ) else {
            throw Failure.unexpectedInteraction
        }

        guard interaction.handle(
            .escape
        ) == .unhandled else {
            throw Failure.unexpectedInteraction
        }
    }

    private static func runScrollableDocumentProbe() throws {
        var document = TerminalScrollableDocument(
            lines: (1...20).map {
                "row \($0)"
            },
            visibleRows: 4
        )

        guard document.handle(
            .motion(
                .down
            )
        ),
        document.viewport.offset == 1 else {
            throw Failure.unexpectedDocument
        }

        guard document.handle(
            .motion(
                .pageDown
            )
        ),
        document.viewport.offset == 4 else {
            throw Failure.unexpectedDocument
        }

        guard document.handle(
            .motion(
                .documentEnd
            )
        ),
        document.viewport.offset == 16,
        document.isFollowingEnd else {
            throw Failure.unexpectedDocument
        }

        document.update(
            lines: (1...24).map {
                "row \($0)"
            },
            visibleRows: 4
        )

        guard document.viewport.offset == 20,
              document.visibleLines == [
                "row 21",
                "row 22",
                "row 23",
                "row 24",
              ] else {
            throw Failure.unexpectedDocument
        }

        document.moveToStart()

        guard document.viewport.offset == 0,
              !document.isFollowingEnd else {
            throw Failure.unexpectedDocument
        }
    }
}
