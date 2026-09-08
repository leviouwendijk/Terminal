import Swim
import Terminal

enum TerminalInteractionFoundationSmoke {
    enum Failure:
        Error
    {
        case unexpectedMode
        case unexpectedInteraction
        case unexpectedDocument
        case unexpectedDocumentScrollHint
        case unexpectedDocumentWordWrapping
        case unexpectedDocumentDisplayWrapping
        case unexpectedDocumentANSIWrapping
        case unexpectedDocumentLayer
    }

    static func run() throws {
        try runModalInteractionProbe()
        try runScrollableDocumentProbe()
    }

    private static func runModalInteractionProbe() throws {
        var interaction = Swim.ModalInteraction()

        guard interaction.mode == .normal,
              interaction.handle(
                .char("I")
              ) == .action(
                .command(
                    .edit(
                        .insertAtFirstNonWhitespace
                    )
                )
              ),
              interaction.mode == .normal,
              interaction.handle(
                .char("A")
              ) == .action(
                .command(
                    .edit(
                        .appendAtLineEnd
                    )
                )
              ),
              interaction.handle(
                .char("o")
              ) == .action(
                .command(
                    .edit(
                        .openLineBelow
                    )
                )
              ),
              interaction.handle(
                .char("O")
              ) == .action(
                .command(
                    .edit(
                        .openLineAbove
                    )
                )
              ),
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
            .enterVisual(
                .character
            )
        ),
        interaction.mode == .visual,
        interaction.visualSelectionKind == .character else {
            throw Failure.unexpectedMode
        }

        guard interaction.handle(
            .char("j")
        ) == .action(
            .command(
                .motion(
                    .down,
                    count: 1
                )
            )
        ) else {
            throw Failure.unexpectedInteraction
        }

        guard interaction.handle(
            .char("V")
        ) == .action(
            .enterVisual(
                .line
            )
        ),
        interaction.mode == .visual,
        interaction.visualSelectionKind == .line else {
            throw Failure.unexpectedMode
        }

        guard interaction.handle(
            .control("V")
        ) == .action(
            .enterVisual(
                .block
            )
        ),
        interaction.mode == .visual,
        interaction.visualSelectionKind == .block else {
            throw Failure.unexpectedMode
        }

        guard interaction.handle(
            .char("v")
        ) == .action(
            .enterVisual(
                .character
            )
        ),
        interaction.mode == .visual,
        interaction.visualSelectionKind == .character else {
            throw Failure.unexpectedMode
        }

        guard interaction.handle(
            .char("v")
        ) == .action(
            .returnToNormal
        ),
        interaction.mode == .normal,
        interaction.visualSelectionKind == nil else {
            throw Failure.unexpectedMode
        }

        guard interaction.handle(
            .char("g")
        ) == .consumed,
        interaction.handle(
            .char("g")
        ) == .action(
            .command(
                .motion(
                    .documentStart,
                    count: 1
                )
            )
        ) else {
            throw Failure.unexpectedInteraction
        }

        guard interaction.handle(
            .char("2")
        ) == .consumed,
        interaction.handle(
            .char("3")
        ) == .consumed,
        interaction.handle(
            .char("j")
        ) == .action(
            .command(
                .motion(
                    .down,
                    count: 23
                )
            )
        ) else {
            throw Failure.unexpectedInteraction
        }

        guard interaction.handle(
            .char("c")
        ) == .consumed,
        interaction.handle(
            .char("w")
        ) == .action(
            .command(
                .operate(
                    .change,
                    target:
                        .motion(
                            .wordForward,
                            count: 1
                        )
                )
            )
        ) else {
            throw Failure.unexpectedInteraction
        }

        guard interaction.handle(
            .char("r")
        ) == .consumed,
        interaction.handle(
            .char("!")
        ) == .action(
            .command(
                .replaceCharacters(
                    replacement: "!",
                    count: 1
                )
            )
        ) else {
            throw Failure.unexpectedInteraction
        }

        guard interaction.handle(
            .char("3")
        ) == .consumed,
        interaction.handle(
            .char("r")
        ) == .consumed,
        interaction.handle(
            .space
        ) == .action(
            .command(
                .replaceCharacters(
                    replacement: " ",
                    count: 3
                )
            )
        ) else {
            throw Failure.unexpectedInteraction
        }

        guard interaction.handle(
            .char("r")
        ) == .consumed,
        interaction.handle(
            .escape
        ) == .consumed,
        interaction.mode == .normal,
        interaction.handle(
            .escape
        ) == .unhandled else {
            throw Failure.unexpectedInteraction
        }

        guard interaction.handle(
            .char("2")
        ) == .consumed,
        interaction.handle(
            .char("i")
        ) == .action(
            .enterInsert(
                .beforeCursor
            )
        ),
        interaction.mode == .insert else {
            throw Failure.unexpectedInteraction
        }

        _ = interaction.handle(
            .escape
        )

        guard interaction.mode == .normal else {
            throw Failure.unexpectedMode
        }

        guard interaction.handle(
            .char("R")
        ) == .action(
            .command(
                .edit(
                    .enterReplaceMode
                )
            )
        ) else {
            throw Failure.unexpectedInteraction
        }

        interaction.setMode(
            .replace
        )

        guard interaction.handle(
            .char("X")
        ) == .action(
            .literal(
                .char("X")
            )
        ),
        interaction.handle(
            .backspace
        ) == .action(
            .literal(
                .backspace
            )
        ),
        interaction.handle(
            .escape
        ) == .action(
            .returnToNormal
        ),
        interaction.mode == .normal else {
            throw Failure.unexpectedInteraction
        }

        guard interaction.handle(
            .char("J")
        ) == .action(
            .command(
                .joinLines(
                    count: 2
                )
            )
        ),
        interaction.handle(
            .char("3")
        ) == .consumed,
        interaction.handle(
            .char("~")
        ) == .action(
            .command(
                .toggleCase(
                    count: 3
                )
            )
        ) else {
            throw Failure.unexpectedInteraction
        }

        guard interaction.handle(
            .char(">")
        ) == .consumed,
        interaction.handle(
            .char(">")
        ) == .action(
            .command(
                .operate(
                    .shiftRight,
                    target:
                        .line(
                            count: 1
                        )
                )
            )
        ),
        interaction.handle(
            .char("3")
        ) == .consumed,
        interaction.handle(
            .char("<")
        ) == .consumed,
        interaction.handle(
            .char("<")
        ) == .action(
            .command(
                .operate(
                    .shiftLeft,
                    target:
                        .line(
                            count: 3
                        )
                )
            )
        ) else {
            throw Failure.unexpectedInteraction
        }

        guard interaction.handle(
            .char(">")
        ) == .consumed,
        interaction.handle(
            .char("j")
        ) == .action(
            .command(
                .operate(
                    .shiftRight,
                    target:
                        .motion(
                            .down,
                            count: 1
                        )
                )
            )
        ) else {
            throw Failure.unexpectedInteraction
        }

        guard interaction.handle(
            .char("D")
        ) == .action(
            .command(
                .operate(
                    .delete,
                    target:
                        .motion(
                            .lineEnd,
                            count: 1
                        )
                )
            )
        ),
        interaction.handle(
            .char("2")
        ) == .consumed,
        interaction.handle(
            .char("C")
        ) == .action(
            .command(
                .operate(
                    .change,
                    target:
                        .motion(
                            .lineEnd,
                            count: 2
                        )
                )
            )
        ),
        interaction.handle(
            .char("3")
        ) == .consumed,
        interaction.handle(
            .char("S")
        ) == .action(
            .command(
                .operate(
                    .change,
                    target:
                        .line(
                            count: 3
                        )
                )
            )
        ),
        interaction.handle(
            .char("4")
        ) == .consumed,
        interaction.handle(
            .char("s")
        ) == .action(
            .command(
                .operate(
                    .change,
                    target:
                        .characters(
                            count: 4
                        )
                )
            )
        ) else {
            throw Failure.unexpectedInteraction
        }

        guard interaction.handle(
            .char("v")
        ) == .action(
            .enterVisual(
                .character
            )
        ),
        interaction.handle(
            .char("c")
        ) == .action(
            .change
        ),
        interaction.mode == .normal else {
            throw Failure.unexpectedInteraction
        }

        guard interaction.handle(
            .control("V")
        ) == .action(
            .enterVisual(
                .block
            )
        ),
        interaction.handle(
            .char("c")
        ) == .action(
            .enterBlockInsert(
                .change
            )
        ),
        interaction.mode == .insert,
        interaction.visualSelectionKind == nil else {
            throw Failure.unexpectedInteraction
        }

        _ = interaction.handle(
            .escape
        )

        guard interaction.handle(
            .control("V")
        ) == .action(
            .enterVisual(
                .block
            )
        ),
        interaction.handle(
            .char("I")
        ) == .action(
            .enterBlockInsert(
                .insertBefore
            )
        ),
        interaction.mode == .insert else {
            throw Failure.unexpectedInteraction
        }

        _ = interaction.handle(
            .escape
        )

        guard interaction.handle(
            .control("V")
        ) == .action(
            .enterVisual(
                .block
            )
        ),
        interaction.handle(
            .char("A")
        ) == .action(
            .enterBlockInsert(
                .insertAfter
            )
        ),
        interaction.mode == .insert else {
            throw Failure.unexpectedInteraction
        }

        guard interaction.handle(
            .escape
        ) == .action(
            .returnToNormal
        ),
        interaction.mode == .normal else {
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

        guard document.handle(
            .command(
                .motion(
                    .down,
                    count: 3
                )
            )
        ),
        document.viewport.offset == 3 else {
            throw Failure.unexpectedDocument
        }

        document.moveToStart()

        let region = TerminalRegion(
            rows: 4,
            columns: 12
        )
        var initialFrame = TerminalFrame(
            rows: 4,
            columns: 12
        )

        document.render(
            into: &initialFrame,
            in: region
        )

        _ = document.handle(
            .motion(
                .down
            )
        )

        var scrolledFrame = TerminalFrame(
            rows: 4,
            columns: 12
        )

        document.render(
            into: &scrolledFrame,
            in: region
        )

        guard scrolledFrame.scrolls == [
            TerminalFrameScroll(
                top: 0,
                rows: 4,
                delta: 1
            ),
        ] else {
            throw Failure.unexpectedDocumentScrollHint
        }

        var wordDocument = TerminalScrollableDocument()

        wordDocument.update(
            text: "The parent run remains on hold until an explicit recovery action is chosen.",
            columns: 18,
            visibleRows: 6,
            wrapping: .word
        )

        guard wordDocument.lines == [
            "The parent run",
            "remains on hold",
            "until an explicit",
            "recovery action is",
            "chosen.",
        ] else {
            throw Failure.unexpectedDocumentWordWrapping
        }

        var displayDocument = TerminalScrollableDocument()

        displayDocument.update(
            text: "abcdef\nxy",
            columns: 3,
            visibleRows: 4,
            wrapping: .display
        )

        guard displayDocument.lines == [
            "abc",
            "def",
            "xy",
        ] else {
            throw Failure.unexpectedDocumentDisplayWrapping
        }

        let styled =
            TerminalStyle(
                .green
            ).apply(
                "abcdef"
            )
            + "\n"
            + TerminalStyle(
                .red
            ).apply(
                "xy"
            )
        var ansiDocument = TerminalScrollableDocument()

        ansiDocument.update(
            text: styled,
            columns: 3,
            visibleRows: 4,
            wrapping: .display
        )

        guard ansiDocument.lines.map({
            stripANSI(
                $0
            )
        }) == [
            "abc",
            "def",
            "xy",
        ],
        ansiDocument.lines.map({
            TerminalDisplay.width(
                of: $0
            )
        }) == [
            3,
            3,
            2,
        ],
        ansiDocument.lines.allSatisfy({
            $0.contains(
                "\u{001B}["
            )
        }) else {
            throw Failure.unexpectedDocumentANSIWrapping
        }

        let nestedLayer = TerminalZIndex(
            200
        )
        let layeredRegion = TerminalRegion(
            rows: 1,
            columns: 12
        )
        var layeredFrame = TerminalFrame(
            rows: 1,
            columns: 12
        )
        var layeredDocument = TerminalScrollableDocument(
            lines: [
                "nested",
            ],
            visibleRows: 1
        )

        layeredFrame.write(
            "underneath",
            in: layeredRegion,
            zIndex: .overlay
        )
        layeredDocument.render(
            into: &layeredFrame,
            in: layeredRegion,
            zIndex: nestedLayer
        )

        let layeredResolved = layeredFrame.resolvedSpans(
            inRow: 0
        )
        let layeredText = layeredResolved
            .map {
                stripANSI(
                    $0.content
                )
            }
            .joined()

        guard layeredText.hasPrefix(
            "nested"
        ),
              !layeredText.contains(
                "underneath"
              ) else {
            throw Failure.unexpectedDocumentLayer
        }
    }
}
