import Difference
import Foundation
import Terminal

private enum TerminalOverlaySmokeFocus:
    Sendable,
    Hashable
{
    case base
    case approval
    case inspector
}

private enum TerminalOverlaySmokeInspector:
    Sendable,
    Hashable
{
    case details
    case difference

    var title: String {
        switch self {
        case .details:
            return "tool details"

        case .difference:
            return "staged diff"
        }
    }
}

private enum TerminalOverlaySmokeApprovalChoice:
    Sendable,
    Hashable
{
    case approve
    case inspectDetails
    case showDiff
    case deny

    var title: String {
        switch self {
        case .approve:
            return "Approve"

        case .inspectDetails:
            return "Inspect details"

        case .showDiff:
            return "Show diff"

        case .deny:
            return "Deny"
        }
    }
}

private struct TerminalOverlaySmokeMessage:
    Sendable
{
    var role: String
    var body: String
}

enum TerminalOverlaySmoke {
    static func run() throws {
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
        var focus = TerminalFocusStack(
            TerminalOverlaySmokeFocus.base
        )
        var composer = TerminalTextInputControl(
            prompt: "> ",
            placeholder: "type a message..."
        )
        var approval = TerminalListControl(
            items: approvalItems,
            currentID: TerminalOverlaySmokeApprovalChoice.approve,
            id: {
                $0.id
            }
        )
        var inspector: TerminalOverlaySmokeInspector?
        var inspectorDocument = TerminalScrollableDocument(
            visibleRows: 0
        )
        var inspectorInteraction = TerminalModalInteraction(
            mode: .normal
        )
        var messages = [
            TerminalOverlaySmokeMessage(
                role: "you",
                body: "Keep the underlying shell alive while transient interfaces appear above it."
            ),
            TerminalOverlaySmokeMessage(
                role: "assistant",
                body: "The frame can now prove modal focus capture without changing application semantics."
            ),
        ]

        while true {
            renderer.render(
                frame(
                    size: Terminal.size(
                        for: stream
                    ),
                    focus: focus,
                    composer: composer,
                    approval: approval,
                    inspector: inspector,
                    inspectorDocument: &inspectorDocument,
                    messages: messages
                )
            )

            guard let key = reader.readKey(
                timeoutMilliseconds: 100
            ) else {
                continue
            }

            switch focus.current {
            case .base:
                switch key {
                case .control("C"),
                     .control("D"):
                    return

                case .control("O"):
                    _ = approval.select(
                        id: .approve
                    )
                    focus.push(
                        .approval
                    )

                case .enter:
                    submit(
                        composer: &composer,
                        messages: &messages
                    )

                default:
                    _ = composer.handle(
                        key
                    )
                }

            case .approval:
                switch key {
                case .control("C"):
                    return

                case .escape:
                    _ = focus.pop()

                default:
                    guard case .accepted(let choice)? =
                        approval.handle(
                            key
                        ) else {
                        continue
                    }

                    switch choice {
                    case .approve:
                        messages.append(
                            TerminalOverlaySmokeMessage(
                                role: "system",
                                body: "Approval accepted. Underlying shell state remained intact."
                            )
                        )
                        _ = focus.pop()

                    case .deny:
                        messages.append(
                            TerminalOverlaySmokeMessage(
                                role: "system",
                                body: "Approval denied. Underlying shell state remained intact."
                            )
                        )
                        _ = focus.pop()

                    case .inspectDetails:
                        inspector = .details
                        inspectorDocument.moveToStart()
                        inspectorInteraction.setMode(
                            .normal
                        )
                        focus.push(
                            .inspector
                        )

                    case .showDiff:
                        inspector = .difference
                        inspectorDocument.moveToStart()
                        inspectorInteraction.setMode(
                            .normal
                        )
                        focus.push(
                            .inspector
                        )
                    }
                }

            case .inspector:
                if key == .control("C") {
                    return
                }

                switch inspectorInteraction.handle(
                    key
                ) {
                case .consumed:
                    continue

                case .unhandled:
                    guard key == .escape else {
                        continue
                    }

                    inspector = nil
                    _ = focus.pop()

                case .action(let action):
                    if !inspectorDocument.handle(
                        action
                    ) {
                        inspectorInteraction.setMode(
                            .normal
                        )
                    }
                }
            }
        }
    }

    private struct ApprovalItem:
        Sendable
    {
        var id: TerminalOverlaySmokeApprovalChoice
        var title: String
    }

    private static let approvalItems = [
        ApprovalItem(
            id: .approve,
            title: TerminalOverlaySmokeApprovalChoice.approve.title
        ),
        ApprovalItem(
            id: .inspectDetails,
            title: TerminalOverlaySmokeApprovalChoice.inspectDetails.title
        ),
        ApprovalItem(
            id: .showDiff,
            title: TerminalOverlaySmokeApprovalChoice.showDiff.title
        ),
        ApprovalItem(
            id: .deny,
            title: TerminalOverlaySmokeApprovalChoice.deny.title
        ),
    ]

    private static func submit(
        composer: inout TerminalTextInputControl,
        messages: inout [TerminalOverlaySmokeMessage]
    ) {
        let text = composer.input.text
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !text.isEmpty else {
            return
        }

        messages.append(
            TerminalOverlaySmokeMessage(
                role: "you",
                body: text
            )
        )
        messages.append(
            TerminalOverlaySmokeMessage(
                role: "assistant",
                body: "Composer state and transcript mutation remain owned by the base shell."
            )
        )
        composer.clear()
    }

    private static func frame(
        size: TerminalSize,
        focus: TerminalFocusStack<TerminalOverlaySmokeFocus>,
        composer: TerminalTextInputControl,
        approval: TerminalListControl<
            ApprovalItem,
            TerminalOverlaySmokeApprovalChoice
        >,
        inspector: TerminalOverlaySmokeInspector?,
        inspectorDocument: inout TerminalScrollableDocument,
        messages: [TerminalOverlaySmokeMessage]
    ) -> TerminalFrame {
        var frame = baseFrame(
            size: size,
            composer: composer,
            composerFocused:
                focus.current == .base,
            messages: messages
        )
        let root = TerminalRegion(
            rows: size.rows,
            columns: size.columns
        )

        switch focus.current {
        case .base:
            break

        case .approval:
            renderApproval(
                into: &frame,
                in: root,
                approval: approval
            )

        case .inspector:
            renderApproval(
                into: &frame,
                in: root,
                approval: approval
            )

            if let inspector {
                renderInspector(
                    inspector,
                    into: &frame,
                    in: root,
                    document: &inspectorDocument
                )
            }
        }

        return frame
    }

    private static func baseFrame(
        size: TerminalSize,
        composer: TerminalTextInputControl,
        composerFocused: Bool,
        messages: [TerminalOverlaySmokeMessage]
    ) -> TerminalFrame {
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
        let vertical = TerminalLayout.vertical(
            in: root,
            [
                .fixed(2),
                .flex(1),
                .fixed(4),
            ],
            spacing: 1
        )
        let header = vertical[0]
        let body = vertical[1]
        let footer = vertical[2]

        frame.write(
            [
                TerminalStyle.bold.apply(
                    "terminal shell"
                ),
                TerminalStyle.dim.apply(
                    "overlay composition laboratory"
                ),
            ],
            in: header
        )

        let railColumns = min(
            18,
            max(
                8,
                body.columns / 3
            )
        )
        let horizontal = TerminalLayout.horizontal(
            in: body,
            [
                .fixed(railColumns),
                .flex(1),
            ],
            spacing: 2
        )

        frame.write(
            [
                TerminalStyle.dim.apply(
                    "sessions"
                ),
                TerminalStyle.bold.apply(
                    "  current"
                ),
                "  previous",
                "",
                TerminalStyle.dim.apply(
                    "views"
                ),
                "  runs",
                "  tools",
                "  tasks",
            ],
            in: horizontal[0]
        )

        frame.write(
            transcriptLines(
                messages,
                width: horizontal[1].columns
            ),
            in: horizontal[1]
        )

        if footer.rows > 0 {
            frame.write(
                TerminalStyle.dim.apply(
                    String(
                        repeating: "─",
                        count: footer.columns
                    )
                ),
                in: TerminalRegion(
                    top: footer.top,
                    leading: footer.leading,
                    rows: 1,
                    columns: footer.columns
                )
            )
        }

        if footer.rows > 1 {
            composer.render(
                into: &frame,
                in: TerminalRegion(
                    top: footer.top + 1,
                    leading: footer.leading,
                    rows: 1,
                    columns: footer.columns
                ),
                isFocused: composerFocused
            )
        }

        if footer.rows > 3 {
            frame.write(
                TerminalStyle.dim.apply(
                    "ctrl-o approval overlay  ctrl-c exit"
                ),
                in: TerminalRegion(
                    top: footer.top + 3,
                    leading: footer.leading,
                    rows: 1,
                    columns: footer.columns
                )
            )
        }

        return frame
    }

    private static func transcriptLines(
        _ messages: [TerminalOverlaySmokeMessage],
        width: Int
    ) -> [String] {
        var lines: [String] = []

        for message in messages {
            lines.append(
                TerminalStyle.bold.apply(
                    message.role
                )
            )
            lines.append(
                contentsOf: TerminalTextWrap.lines(
                    message.body,
                    width: max(
                        1,
                        width
                    )
                )
            )
            lines.append("")
        }

        lines.append(
            TerminalStyle.dim.apply(
                "activity"
            )
        )
        lines.append(
            "base frame remains mounted beneath transient surfaces"
        )

        return lines
    }

    private static func renderApproval(
        into frame: inout TerminalFrame,
        in root: TerminalRegion,
        approval: TerminalListControl<
            ApprovalItem,
            TerminalOverlaySmokeApprovalChoice
        >
    ) {
        let overlay = TerminalOverlay(
            placement: .centered(
                columns: 56,
                rows: 15
            ),
            outerInsets: TerminalInsets(
                vertical: 1,
                horizontal: 2
            )
        )
        let content = overlay.render(
            into: &frame,
            in: root,
            title: "tool approval requested"
        )

        guard !content.isEmpty else {
            return
        }

        var lines = [
            TerminalStyle.bold.apply(
                "mutate_files"
            ),
            "3 file mutations",
            TerminalStyle.dim.apply(
                "risk  medium"
            ),
            "",
        ]

        for row in approval.rows() {
            let line = "  " + row.item.title

            if row.isCurrent {
                lines.append(
                    TerminalStyle(
                        .inverse
                    ).apply(
                        TerminalDisplay.fitted(
                            "> " + row.item.title,
                            columns: content.columns
                        )
                    )
                )
            } else {
                lines.append(
                    line
                )
            }
        }

        lines.append("")
        lines.append(
            TerminalStyle.dim.apply(
                "↑/↓ choose  enter open  esc dismiss"
            )
        )

        frame.write(
            lines,
            in: content
        )
    }

    private static func renderInspector(
        _ inspector: TerminalOverlaySmokeInspector,
        into frame: inout TerminalFrame,
        in root: TerminalRegion,
        document: inout TerminalScrollableDocument
    ) {
        let overlay = TerminalOverlay(
            placement: .trailing(
                columns: 60
            ),
            outerInsets: TerminalInsets(
                vertical: 1,
                horizontal: 1
            )
        )
        let content = overlay.render(
            into: &frame,
            in: root,
            title: inspector.title
        )

        guard !content.isEmpty else {
            return
        }

        let lines = inspectorLines(
            inspector,
            width: content.columns
        )
        let visibleRows = max(
            0,
            content.rows - 2
        )
        let documentRegion = TerminalRegion(
            top: content.top,
            leading: content.leading,
            rows: visibleRows,
            columns: content.columns
        )

        document.update(
            lines: lines,
            visibleRows: visibleRows
        )
        document.render(
            into: &frame,
            in: documentRegion
        )

        if content.rows > 0 {
            frame.write(
                TerminalStyle.dim.apply(
                    "NORMAL  j/k scroll  gg/G ends  pgup/pgdn page  esc back"
                ),
                in: TerminalRegion(
                    top: content.bottom - 1,
                    leading: content.leading,
                    rows: 1,
                    columns: content.columns
                )
            )
        }
    }

    private static func inspectorLines(
        _ inspector: TerminalOverlaySmokeInspector,
        width: Int
    ) -> [String] {
        switch inspector {
        case .details:
            return detailsInspectorLines(
                width: width
            )

        case .difference:
            return differenceInspectorLines
        }
    }

    private static func detailsInspectorLines(
        width: Int
    ) -> [String] {
        let layout = TerminalBlockLayout(
            fieldIndent: 0,
            labelWidth: .minimum(7),
            labelValueSpacing: 3,
            blankLinesAfter: 0
        )
        let blocks = [
            TerminalBlock(
                title: "preflight",
                fields: [
                    TerminalField(
                        "tool",
                        "mutate_files"
                    ),
                    TerminalField(
                        "risk",
                        "medium"
                    ),
                    TerminalField(
                        "targets",
                        "3 files"
                    ),
                ],
                layout: layout
            ),
            TerminalBlock(
                title: "intent",
                body: "Add reusable terminal overlay composition and nested focus restoration.",
                layout: layout
            ),
            TerminalBlock(
                title: "targets",
                body: [
                    "Terminal/Sources/Terminal/terminal-overlay.swift",
                    "Terminal/Sources/Terminal/terminal-focus-stack.swift",
                    "Terminal/Sources/TerminalTestFlows/terminal-overlay-smoke.swift",
                ].joined(
                    separator: "\n"
                ),
                layout: layout
            ),
        ]
        var lines = blocks.flatMap {
            block in

            block.render(
                width: width
            )
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .map(String.init)
        }

        lines.append(
            contentsOf: TerminalTextWrap.lines(
                "This content is deliberately longer than the smallest sheet so viewport behavior can be inspected.",
                width: width
            ).map(
                TerminalStyle.dim.apply
            )
        )

        return lines
    }

    private static let differenceInspectorLines: [String] = {
        let oldLines = (1...96).map {
            index in

            "let overlayRow\(index) = \"base-\(index)\""
        }
        var newLines = oldLines

        for index in stride(
            from: 4,
            through: 92,
            by: 8
        ) {
            newLines[index - 1] =
                "let overlayRow\(index) = \"composed-\(index)\""
        }

        newLines.insert(
            "let overlayStack = \"approval > diff inspector\"",
            at: 18
        )
        newLines.remove(
            at: 73
        )

        let difference = TextDiffer.diff(
            old: oldLines.joined(
                separator: "\n"
            ),
            new: newLines.joined(
                separator: "\n"
            ),
            oldName: "a/terminal-overlay-smoke.swift",
            newName: "b/terminal-overlay-smoke.swift"
        )

        return TerminalDifferenceRenderer.render(
            difference,
            options: .init(
                base: .init(
                    showEndOfFile: true
                )
            )
        )
        .split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        .map(String.init)
    }()
}
