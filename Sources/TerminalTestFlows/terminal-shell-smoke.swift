import Foundation
import Terminal

private enum TerminalShellFocus:
    Sendable,
    Hashable
{
    case navigation
    case composer
}

private enum TerminalShellDestination:
    Sendable,
    Hashable
{
    case current
    case previous
    case runs
    case tools
    case tasks

    var title: String {
        switch self {
        case .current:
            return "current"

        case .previous:
            return "previous"

        case .runs:
            return "runs"

        case .tools:
            return "tools"

        case .tasks:
            return "tasks"
        }
    }
}

private struct TerminalShellNavigationItem:
    Sendable
{
    var id: TerminalShellDestination
    var title: String
}

private struct TerminalShellMessage:
    Sendable
{
    var role: String
    var body: String
}

enum TerminalShellSmoke {
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
        var focus = TerminalFocusState(
            order: [
                TerminalShellFocus.navigation,
                .composer,
            ],
            focused: .composer
        )
        var navigation = TerminalListControl(
            items: navigationItems,
            currentID: TerminalShellDestination.current,
            id: {
                $0.id
            }
        )
        var destination =
            TerminalShellDestination.current
        var composer = TerminalTextInputControl(
            prompt: "> ",
            placeholder: "type a message..."
        )
        var messages = [
            TerminalShellMessage(
                role: "you",
                body:
                    "Build a stable interactive terminal shell."
            ),
            TerminalShellMessage(
                role: "assistant",
                body:
                    "Frame composition now owns positioned output without owning runtime semantics."
            ),
        ]
        var viewport = TerminalViewport(
            visibleRows: 0
        )
        var revealEnd = true

        while true {
            renderer.render(
                frame(
                    size: Terminal.size(
                        for: stream
                    ),
                    focus: focus.focused,
                    navigation: navigation,
                    destination: destination,
                    composer: composer,
                    messages: messages,
                    viewport: &viewport,
                    revealEnd: &revealEnd
                )
            )

            guard let key = reader.readKey(
                timeoutMilliseconds: 100
            ) else {
                continue
            }

            switch key {
            case .control("C"),
                 .control("D"):
                return

            case .tab:
                _ = focus.moveNext()
                continue

            case .pageUp:
                viewport.pageUp()
                revealEnd = false
                continue

            case .pageDown:
                viewport.pageDown()
                revealEnd = false
                continue

            default:
                break
            }

            switch focus.focused {
            case .navigation?:
                switch key {
                case .char("q"):
                    return

                case .escape:
                    _ = focus.focus(
                        .composer
                    )

                default:
                    if case .accepted(let selected)? =
                        navigation.handle(
                            key
                        ) {
                        destination = selected
                        viewport.moveToStart()
                        revealEnd =
                            selected == .current
                    }
                }

            case .composer?:
                if key == .escape {
                    _ = focus.focus(
                        .navigation
                    )
                    continue
                }

                if key == .enter {
                    submit(
                        composer: &composer,
                        messages: &messages,
                        navigation: &navigation,
                        destination: &destination,
                        revealEnd: &revealEnd
                    )
                    continue
                }

                _ = composer.handle(
                    key
                )

            case nil:
                _ = focus.focus(
                    .composer
                )
            }
        }
    }

    private static let navigationItems = [
        TerminalShellNavigationItem(
            id: .current,
            title: "current"
        ),
        TerminalShellNavigationItem(
            id: .previous,
            title: "previous"
        ),
        TerminalShellNavigationItem(
            id: .runs,
            title: "runs"
        ),
        TerminalShellNavigationItem(
            id: .tools,
            title: "tools"
        ),
        TerminalShellNavigationItem(
            id: .tasks,
            title: "tasks"
        ),
    ]

    private static func submit(
        composer: inout TerminalTextInputControl,
        messages: inout [TerminalShellMessage],
        navigation: inout TerminalListControl<
            TerminalShellNavigationItem,
            TerminalShellDestination
        >,
        destination: inout TerminalShellDestination,
        revealEnd: inout Bool
    ) {
        let text = composer.input.text
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !text.isEmpty else {
            return
        }

        messages.append(
            TerminalShellMessage(
                role: "you",
                body: text
            )
        )
        messages.append(
            TerminalShellMessage(
                role: "assistant",
                body:
                    "Message accepted. The outer TerminalSession stayed alive while the transcript and composer redrew in place."
            )
        )

        composer.clear()
        destination = .current
        _ = navigation.select(
            id: .current
        )
        revealEnd = true
    }

    private static func frame(
        size: TerminalSize,
        focus: TerminalShellFocus?,
        navigation: TerminalListControl<
            TerminalShellNavigationItem,
            TerminalShellDestination
        >,
        destination: TerminalShellDestination,
        composer: TerminalTextInputControl,
        messages: [TerminalShellMessage],
        viewport: inout TerminalViewport,
        revealEnd: inout Bool
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
                    "persistent frame composition · \(destination.title)"
                ),
            ],
            in: header
        )

        let railColumns = min(
            18,
            max(
                10,
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
        let navigationRegion = horizontal[0]
        let mainRegion = horizontal[1]

        frame.write(
            navigationLines(
                rows: navigation.rows(),
                active: destination,
                isFocused:
                    focus == .navigation
            ),
            in: navigationRegion
        )

        let content = contentLines(
            for: destination,
            messages: messages,
            width: mainRegion.columns
        )
        let wasAtEnd = viewport.isAtEnd

        viewport.update(
            contentRows: content.count,
            visibleRows: mainRegion.rows
        )

        let shouldRevealEnd =
            revealEnd
            || (
                wasAtEnd
                && destination == .current
            )

        if shouldRevealEnd {
            viewport.moveToEnd()
        }

        revealEnd = false

        frame.write(
            viewport.visibleRange.map {
                content[$0]
            },
            in: mainRegion
        )

        let separatorRegion = TerminalRegion(
            top: footer.top,
            leading: footer.leading,
            rows: min(
                1,
                footer.rows
            ),
            columns: footer.columns
        )

        frame.write(
            TerminalStyle.dim.apply(
                String(
                    repeating: "─",
                    count: footer.columns
                )
            ),
            in: separatorRegion
        )

        if footer.rows > 1 {
            composer.render(
                into: &frame,
                in: TerminalRegion(
                    top: footer.top + 1,
                    leading: footer.leading,
                    rows: 1,
                    columns: footer.columns
                ),
                isFocused:
                    focus == .composer
            )
        }

        if footer.rows > 3 {
            frame.write(
                TerminalStyle.dim.apply(
                    keyHints(
                        focus: focus
                    )
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

    private static func navigationLines(
        rows: [
            TerminalListControlRow<
                TerminalShellNavigationItem,
                TerminalShellDestination
            >
        ],
        active: TerminalShellDestination,
        isFocused: Bool
    ) -> [String] {
        var lines = [
            TerminalStyle.dim.apply(
                "sessions"
            ),
        ]

        for row in rows.prefix(2) {
            lines.append(
                navigationLine(
                    row,
                    active: active,
                    isFocused: isFocused
                )
            )
        }

        lines.append("")
        lines.append(
            TerminalStyle.dim.apply(
                "views"
            )
        )

        for row in rows.dropFirst(2) {
            lines.append(
                navigationLine(
                    row,
                    active: active,
                    isFocused: isFocused
                )
            )
        }

        return lines
    }

    private static func navigationLine(
        _ row: TerminalListControlRow<
            TerminalShellNavigationItem,
            TerminalShellDestination
        >,
        active: TerminalShellDestination,
        isFocused: Bool
    ) -> String {
        let marker: String

        if isFocused && row.isCurrent {
            marker = "> "
        } else {
            marker = "  "
        }

        let line = marker + row.item.title

        guard row.id == active else {
            return line
        }

        return TerminalStyle.bold.apply(
            line
        )
    }

    private static func contentLines(
        for destination: TerminalShellDestination,
        messages: [TerminalShellMessage],
        width: Int
    ) -> [String] {
        switch destination {
        case .current:
            return transcriptLines(
                messages: messages,
                width: width
            )

        case .previous:
            return [
                TerminalStyle.bold.apply(
                    "you"
                ),
                "Keep the shell sparse.",
                "",
                TerminalStyle.bold.apply(
                    "assistant"
                ),
                "Geometry and state should do the work; the application owns the meaning.",
                "",
                TerminalStyle.dim.apply(
                    "activity"
                ),
                "session inactive",
            ]

        case .runs:
            return [
                TerminalStyle.bold.apply(
                    "runs"
                ),
                "current run       active",
                "frame probe       completed",
                "",
                TerminalStyle.dim.apply(
                    "mock view"
                ),
                "runtime-backed run state comes later",
            ]

        case .tools:
            return [
                TerminalStyle.bold.apply(
                    "tools"
                ),
                "frame renderer    ready",
                "text input        ready",
                "list control      ready",
                "",
                TerminalStyle.dim.apply(
                    "mock view"
                ),
                "Agentic tool activity belongs above Terminal",
            ]

        case .tasks:
            return [
                TerminalStyle.bold.apply(
                    "tasks"
                ),
                "interactive shell          active",
                "overlay composition        next",
                "runtime interface bridge   pending",
                "",
                TerminalStyle.dim.apply(
                    "mock view"
                ),
                "task semantics belong to consumers",
            ]
        }
    }

    private static func transcriptLines(
        messages: [TerminalShellMessage],
        width: Int
    ) -> [String] {
        var lines: [String] = []
        let width = max(
            1,
            width
        )

        for message in messages {
            lines.append(
                TerminalStyle.bold.apply(
                    message.role
                )
            )
            lines.append(
                contentsOf: TerminalTextWrap.lines(
                    message.body,
                    width: width
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
            "rendering dirty rows only"
        )

        return lines
    }

    private static func keyHints(
        focus: TerminalShellFocus?
    ) -> String {
        switch focus {
        case .navigation?:
            return "j/k move  enter open  tab composer  q exit"

        case .composer?:
            return "tab navigation  pgup/pgdn transcript  esc navigation  ctrl-c exit"

        case nil:
            return "tab focus  ctrl-c exit"
        }
    }
}
