import Terminal

private struct TerminalSmokeItem: Sendable, Hashable {
    var id: Int
    var title: String
    var isEnabled: Bool
}

enum TerminalInteractiveSmoke {
    static func runKeyProbe() throws {
        let session = try TerminalSession(
            options: .interactive
        )

        defer {
            session.restore()
        }

        let reader = TerminalKeyReader()

        Terminal.clearScreen()
        Terminal.moveCursor(
            line: 1,
            column: 1
        )
        Terminal.write(
            "Terminal key probe\n",
            to: .standardError
        )
        Terminal.write(
            "Press keys. Esc, Ctrl-C, or Ctrl-D exits.\n\n",
            to: .standardError
        )

        while true {
            let key = reader.readKey()

            Terminal.write(
                "key: \(key.description)\n",
                to: .standardError
            )

            if key.isExitLike {
                return
            }
        }
    }

    static func runListProbe() throws {
        Terminal.write(
            """
            Existing view above the inline picker.

            The picker below should redraw only its own region. Item 3 is visible
            but disabled. When you press Enter, the picker collapses into a
            final summary instead of clearing the whole terminal.

            """,
            to: .standardError
        )

        let list = TerminalInteractiveList<TerminalSmokeItem, Int>(
            items: approvalItems(),
            configuration: .inline(
                title: "Terminal inline list probe",
                instructions: "Ctrl-P/up and Ctrl-N/down move. Space toggles. Enter accepts. q/Esc exits.",
                allowsMultipleSelection: true,
                wrapMode: .wrap,
                outputStream: .standardError,
                completionPresentation: .leaveSummary
            ),
            id: { item in
                item.id
            },
            isEnabled: { item in
                item.isEnabled
            },
            row: { row in
                if !row.isEnabled {
                    return "  [-] \(row.item.title)\n"
                }

                let cursor = row.isCurrent ? ">" : " "
                let marker = row.isSelected ? "x" : " "

                return "\(cursor) [\(marker)] \(row.item.title)\n"
            },
            summary: { result in
                listSummary(
                    result
                )
            }
        )

        _ = try list.run()
    }

    static func runMenuProbe() throws {
        Terminal.write(
            """
            Existing view above the inline menu.

            The menu below allows exactly one picked option. There is no toggle
            state. Move with Ctrl-P/Ctrl-N, arrows, or k/j, then press Enter to pick.

            """,
            to: .standardError
        )

        let menu = TerminalInteractiveMenu<TerminalSmokeItem, Int>(
            items: approvalItems(),
            configuration: .inline(
                title: "Terminal inline menu probe",
                instructions: "Ctrl-P/Ctrl-N, ↑/↓, or k/j move. Enter picks. q/Esc exits.",
                wrapMode: .wrap,
                outputStream: .standardError,
                completionPresentation: .leaveSummary
            ),
            id: { item in
                item.id
            },
            isEnabled: { item in
                item.isEnabled
            },
            row: { row in
                if !row.isEnabled {
                    return "  - \(row.item.title)\n"
                }

                let cursor = row.isCurrent ? ">" : " "

                return "\(cursor) \(row.item.title)\n"
            },
            summary: { result in
                menuSummary(
                    result
                )
            }
        )

        _ = try menu.run()
    }

    static func runColorMenuProbe() throws {
        Terminal.write(
            """
            Existing view above the styled inline menu.

            This variant colors rows, leaves a colored final summary, and then
            runs a post-pick callback after the menu has returned.

            """,
            to: .standardError
        )

        let menu = TerminalInteractiveMenu<TerminalSmokeItem, Int>(
            items: approvalItems(),
            configuration: .inline(
                title: "Styled approval menu",
                instructions: "Move with Ctrl-P/Ctrl-N, ↑/↓, or k/j. Enter picks. q/Esc exits.",
                wrapMode: .wrap,
                outputStream: .standardError,
                completionPresentation: .leaveSummary
            ),
            id: { item in
                item.id
            },
            isEnabled: { item in
                item.isEnabled
            },
            row: { row in
                styledMenuRow(
                    row
                )
            },
            summary: { result in
                styledMenuSummary(
                    result
                )
            }
        )

        let result = try menu.run()

        runPostPickCallback(
            result
        )
    }

    static func runChainedMenuProbe() throws {
        Terminal.write(
            """
            Existing view above the chained menu experiment.

            Pick a primary action. Some actions open a second follow-up menu.
            This tests composing menus at the callsite rather than adding a
            workflow engine to Terminal.

            """,
            to: .standardError
        )

        let first = TerminalInteractiveMenu<TerminalSmokeItem, Int>(
            items: approvalItems(),
            configuration: .inline(
                title: "Primary action",
                instructions: "Pick the action you want to stage.",
                wrapMode: .wrap,
                outputStream: .standardError,
                completionPresentation: .leaveSummary
            ),
            id: { item in
                item.id
            },
            isEnabled: { item in
                item.isEnabled
            },
            row: { row in
                styledMenuRow(
                    row
                )
            },
            summary: { result in
                styledMenuSummary(
                    result
                )
            }
        )

        let firstResult = try first.run()

        guard case .picked(let item, _) = firstResult else {
            Terminal.write(
                "Chain stopped: no primary action picked.\n".ansi(.yellow),
                to: .standardError
            )
            return
        }

        switch item.id {
        case 1:
            try runConfirmFollowUp(
                title: "Approve follow-up",
                message: "Approval was selected. Choose how strongly to confirm it."
            )

        case 2:
            try runConfirmFollowUp(
                title: "Deny follow-up",
                message: "Denial was selected. Choose whether to deny with or without a note."
            )

        case 4:
            try runConfirmFollowUp(
                title: "Inspect follow-up",
                message: "Inspection was selected. Choose which detail view to show next."
            )

        case 5:
            Terminal.write(
                "Chain result: stop run selected.\n".ansi(.yellow, .bold),
                to: .standardError
            )

        default:
            Terminal.write(
                "Chain result: \(item.title)\n",
                to: .standardError
            )
        }
    }

    static func runReviewListProbe() throws {
        Terminal.write(
            """
            Existing view above the review list experiment.

            This variant behaves like a batch review: selected items are rendered
            as accepted decisions after Enter.

            """,
            to: .standardError
        )

        let list = TerminalInteractiveList<TerminalSmokeItem, Int>(
            items: approvalItems(),
            configuration: .inline(
                title: "Review staged decisions",
                instructions: "Space toggles. Enter accepts selected items. Disabled rows remain visible.",
                allowsMultipleSelection: true,
                wrapMode: .wrap,
                outputStream: .standardError,
                completionPresentation: .leaveSummary
            ),
            id: { item in
                item.id
            },
            isEnabled: { item in
                item.isEnabled
            },
            row: { row in
                if !row.isEnabled {
                    return "  [-] \(row.item.title.ansi(.dim))\n"
                }

                let cursor = row.isCurrent ? ">" : " "
                let marker = row.isSelected ? "x" : " "
                let title = row.isSelected
                    ? row.item.title.ansi(.green, .bold)
                    : row.item.title

                return "\(cursor) [\(marker)] \(title)\n"
            },
            summary: { result in
                switch result {
                case .accepted(_, let selected, _):
                    guard !selected.isEmpty else {
                        return """
                        Review result
                        no items selected

                        """.ansi(.yellow)
                    }

                    let lines = selected
                        .map { item in
                            "accepted: \(item.title)".ansi(.green)
                        }
                        .joined(separator: "\n")

                    return """
                    Review result
                    \(lines)

                    """

                case .cancelled:
                    return """
                    Review result
                    cancelled

                    """.ansi(.yellow)
                }
            }
        )

        _ = try list.run()
    }

    private static func runConfirmFollowUp(
        title: String,
        message: String
    ) throws {
        Terminal.write(
            "\n\(message)\n\n",
            to: .standardError
        )

        let followUpItems = [
            TerminalSmokeItem(
                id: 10,
                title: "confirm",
                isEnabled: true
            ),
            TerminalSmokeItem(
                id: 11,
                title: "go back manually",
                isEnabled: true
            ),
            TerminalSmokeItem(
                id: 12,
                title: "cancel chain",
                isEnabled: true
            ),
        ]

        let followUp = TerminalInteractiveMenu<TerminalSmokeItem, Int>(
            items: followUpItems,
            configuration: .inline(
                title: title,
                instructions: "Pick a follow-up action.",
                wrapMode: .wrap,
                outputStream: .standardError,
                completionPresentation: .leaveSummary
            ),
            id: { item in
                item.id
            },
            row: { row in
                let cursor = row.isCurrent ? ">" : " "
                let title = row.item.id == 10
                    ? row.item.title.ansi(.green, .bold)
                    : row.item.title

                return "\(cursor) \(title)\n"
            },
            summary: { result in
                switch result {
                case .picked(let item, _):
                    return """
                    Follow-up result
                    picked: \(item.title)

                    """.ansi(item.id == 10 ? .green : .yellow)

                case .cancelled:
                    return """
                    Follow-up result
                    cancelled

                    """.ansi(.yellow)
                }
            }
        )

        _ = try followUp.run()
    }

    private static func runPostPickCallback(
        _ result: TerminalInteractiveMenuResult<TerminalSmokeItem, Int>
    ) {
        switch result {
        case .picked(let item, _):
            Terminal.write(
                "post-pick callback: \(item.title)\n".ansi(colorForItem(item), .bold),
                to: .standardError
            )

        case .cancelled:
            Terminal.write(
                "post-pick callback: cancelled\n".ansi(.yellow),
                to: .standardError
            )
        }
    }

    private static func styledMenuRow(
        _ row: TerminalInteractiveMenuRow<TerminalSmokeItem, Int>
    ) -> String {
        if !row.isEnabled {
            return "  - \(row.item.title.ansi(.dim))\n"
        }

        let cursor = row.isCurrent ? ">" : " "
        let title = row.item.title.ansi(
            colorForItem(
                row.item
            )
        )

        return "\(cursor) \(title)\n"
    }

    private static func styledMenuSummary(
        _ result: TerminalInteractiveMenuResult<TerminalSmokeItem, Int>
    ) -> String {
        switch result {
        case .picked(let item, _):
            return """
            Menu decision
            picked: \(item.title)

            """.ansi(colorForItem(item), .bold)

        case .cancelled:
            return """
            Menu decision
            cancelled

            """.ansi(.yellow)
        }
    }

    private static func menuSummary(
        _ result: TerminalInteractiveMenuResult<TerminalSmokeItem, Int>
    ) -> String {
        switch result {
        case .picked(let item, _):
            return """
            Menu decision
            picked: \(item.title)

            """

        case .cancelled:
            return """
            Menu decision
            cancelled

            """
        }
    }

    private static func listSummary(
        _ result: TerminalInteractiveListResult<TerminalSmokeItem, Int>
    ) -> String {
        switch result {
        case .accepted(let current, let selected, _):
            let currentTitle = current?.title ?? "none"
            let selectedTitles = selected
                .map(\.title)
                .joined(separator: ", ")

            let selectedText = selectedTitles.isEmpty
                ? "none"
                : selectedTitles

            return """
            Decision summary
            current: \(currentTitle)
            selected: \(selectedText)

            """

        case .cancelled:
            return """
            Decision summary
            cancelled

            """
        }
    }

    private static func colorForItem(
        _ item: TerminalSmokeItem
    ) -> ANSIColor {
        switch item.id {
        case 1:
            return .green

        case 2:
            return .red

        case 4:
            return .cyan

        case 5:
            return .yellow

        default:
            return .defaultText
        }
    }

    private static func approvalItems() -> [TerminalSmokeItem] {
        [
            TerminalSmokeItem(
                id: 1,
                title: "approve",
                isEnabled: true
            ),
            TerminalSmokeItem(
                id: 2,
                title: "deny",
                isEnabled: true
            ),
            TerminalSmokeItem(
                id: 3,
                title: "already blocked by policy",
                isEnabled: false
            ),
            TerminalSmokeItem(
                id: 4,
                title: "inspect details",
                isEnabled: true
            ),
            TerminalSmokeItem(
                id: 5,
                title: "stop run",
                isEnabled: true
            ),
        ]
    }
}

enum TerminalInteractiveBlockSmoke {
    enum Failure:
        Error
    {
        case unexpectedResolvedState
        case unexpectedRoundedBorder
        case unexpectedWidth
        case unexpectedHitRegion
    }

    static func run() throws {
        try proveFoundation()

        let stream = TerminalStream.standardError
        let session = try TerminalSession(
            options: TerminalSession.Options(
                useAlternateScreen: true,
                hideCursor: true,
                useRawMode: true,
                restoreOnInterrupt: true,
                outputStream: stream
            )
        )

        defer {
            session.restore()
        }

        let reader = TerminalKeyReader()
        var renderer = TerminalFrameRenderer(
            stream: stream
        )
        let states = TerminalInteractiveBlockState.allCases
        var selectedState = 1
        var lastActivation = "none"

        while true {
            let size = Terminal.size(
                for: stream
            )
            var frame = TerminalFrame(
                rows: size.rows,
                columns: size.columns
            )
            let root = TerminalRegion(
                rows: size.rows,
                columns: size.columns
            ).inset(
                by: TerminalInsets(
                    vertical: 1,
                    horizontal: 2
                )
            )

            if !root.isEmpty {
                frame.write(
                    [
                        TerminalStyle.bold.apply(
                            "Interactive attached block"
                        ),
                        TerminalStyle.dim.apply(
                            "j/k choose presentation state · enter activate · q close"
                        ),
                    ],
                    in: TerminalRegion(
                        top: root.top,
                        leading: root.leading,
                        rows: min(
                            2,
                            root.rows
                        ),
                        columns: root.columns
                    )
                )

                let cardColumns = min(
                    72,
                    root.columns
                )
                let cardRows = max(
                    0,
                    min(
                        9,
                        root.rows - 4
                    )
                )
                let cardRegion = TerminalRegion(
                    top: root.top + min(2, root.rows),
                    leading: root.leading,
                    rows: cardRows,
                    columns: cardColumns
                )
                let state = states[selectedState]
                let card = TerminalInteractiveBlock(
                    title: "Run · approval required",
                    body: [
                        "Stage 3 of 6 · mutate_files",
                        "2 files · +18 -7",
                        "Human review required",
                    ].joined(separator: "\n"),
                    hint: "Enter for actions",
                    state: state
                )

                _ = card.render(
                    into: &frame,
                    in: cardRegion,
                    zIndex: .overlay
                )

                if root.rows >= 2 {
                    frame.write(
                        TerminalStyle.dim.apply(
                            "state \(state.rawValue) · last activation \(lastActivation)"
                        ),
                        in: TerminalRegion(
                            top: root.bottom - 1,
                            leading: root.leading,
                            rows: 1,
                            columns: root.columns
                        )
                    )
                }
            }

            renderer.render(
                frame
            )

            guard let key = reader.readKey(
                timeoutMilliseconds: 100
            ) else {
                continue
            }

            switch key {
            case .char("q"),
                 .escape:
                return

            case .up,
                 .char("k"):
                selectedState =
                    (selectedState + states.count - 1)
                    % states.count

            case .down,
                 .char("j"):
                selectedState =
                    (selectedState + 1)
                    % states.count

            case .enter:
                let state = states[selectedState]
                lastActivation = state == .disabled
                    ? "blocked (disabled)"
                    : "accepted \(state.rawValue)"

            default:
                continue
            }
        }
    }

    private static func proveFoundation() throws {
        guard TerminalInteractiveBlock.resolvedState(
            isEnabled: false,
            isFocused: true,
            isHovered: true,
            isActive: true
        ) == .disabled,
              TerminalInteractiveBlock.resolvedState(
                isFocused: true,
                isHovered: true
              ) == .focused,
              TerminalInteractiveBlock.resolvedState(
                isHovered: true
              ) == .hovered,
              TerminalInteractiveBlock.resolvedState(
                isActive: true
              ) == .active
        else {
            throw Failure.unexpectedResolvedState
        }

        let block = TerminalInteractiveBlock(
            title: "Run · awaiting review",
            body: "Stage 3 of 6 · mutate_files",
            hint: "Enter for actions",
            state: .focused
        )
        let rendered = block.render(
            width: 48
        )

        guard let first = rendered.first,
              let last = rendered.last,
              stripANSI(first).hasPrefix("╭"),
              stripANSI(first).hasSuffix("╮"),
              stripANSI(last).hasPrefix("╰"),
              stripANSI(last).hasSuffix("╯")
        else {
            throw Failure.unexpectedRoundedBorder
        }

        guard rendered.allSatisfy({ line in
            TerminalDisplay.width(
                of: line
            ) == 48
        }) else {
            throw Failure.unexpectedWidth
        }

        let container = TerminalRegion(
            top: 4,
            leading: 8,
            rows: 10,
            columns: 48
        )
        let hitRegion = block.hitRegion(
            in: container
        )

        guard hitRegion.top == 4,
              hitRegion.leading == 8,
              hitRegion.columns == 48,
              hitRegion.rows == rendered.count,
              block.contains(
                row: hitRegion.top,
                column: hitRegion.leading,
                in: container
              ),
              block.contains(
                row: hitRegion.bottom - 1,
                column: hitRegion.trailing - 1,
                in: container
              ),
              !block.contains(
                row: hitRegion.bottom,
                column: hitRegion.leading,
                in: container
              )
        else {
            throw Failure.unexpectedHitRegion
        }
    }
}
