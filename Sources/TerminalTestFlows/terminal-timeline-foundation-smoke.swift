import Terminal

enum TerminalTimelineFoundationSmoke {
    private enum Step:
        Sendable,
        Hashable
    {
        case mutate
        case build
        case test
        case verify
        case diff
        case branchRepair
        case branchBuild
        case suffix
    }

    static func run() throws {
        let timeline = TerminalTimeline(
            items: [
                TerminalTimelineItem(
                    id: Step.mutate,
                    title: "mutate_files",
                    detail: "Terminal/Sources/Terminal/terminal-timeline.swift",
                    state: .completed
                ),
                TerminalTimelineItem(
                    id: Step.build,
                    title: "swift_build",
                    detail: "Terminal package with a deliberately wrapping detail line",
                    state: .completed
                ),
                TerminalTimelineItem(
                    id: Step.test,
                    title: "artest",
                    detail: "current",
                    state: .active
                ),
                TerminalTimelineItem(
                    id: Step.verify,
                    title: "swift_build",
                    state: .failed
                ),
                TerminalTimelineItem(
                    id: Step.diff,
                    title: "git_diff",
                    state: .skipped
                ),
            ],
            style: .plain
        )
        let layout = timeline.layout(
            width: 24,
            selectedID: .build
        )

        guard layout.itemRows.count == 5,
              let mutateRows = layout.itemRows[.mutate],
              let buildRows = layout.itemRows[.build],
              let testRows = layout.itemRows[.test],
              let verifyRows = layout.itemRows[.verify],
              let diffRows = layout.itemRows[.diff],
              mutateRows.lowerBound < buildRows.lowerBound,
              buildRows.lowerBound < testRows.lowerBound,
              testRows.lowerBound < verifyRows.lowerBound,
              verifyRows.lowerBound < diffRows.lowerBound else {
            throw TerminalTestFailure(
                probe: "TerminalTimeline semantic row ranges",
                expectation: "five ordered item row ranges",
                observed: "\(layout.itemRows)"
            )
        }

        guard layout.lines[mutateRows.lowerBound]
                .contains("✓ mutate_files"),
              layout.lines[buildRows.lowerBound]
                .contains("> ✓ swift_build"),
              layout.lines[testRows.lowerBound]
                .contains("◉ artest"),
              layout.lines[verifyRows.lowerBound]
                .contains("× swift_build"),
              layout.lines[diffRows.lowerBound]
                .contains("─ git_diff") else {
            throw TerminalTestFailure(
                probe: "TerminalTimeline state and selection markers",
                expectation: "completed, selected, active, failed, and skipped markers remain distinct",
                observed: layout.lines.joined(
                    separator: " | "
                )
            )
        }

        guard buildRows.count > 2 else {
            throw TerminalTestFailure(
                probe: "TerminalTimeline wrapped detail rows",
                expectation: "selected build detail wraps across multiple rows",
                observed: "build rows \(buildRows)"
            )
        }

        guard layout.lines.allSatisfy({
            TerminalDisplay.width(
                of: $0
            ) <= 24
        }) else {
            throw TerminalTestFailure(
                probe: "TerminalTimeline width stability",
                expectation: "all rendered rows fit 24 display columns",
                observed: layout.lines
                    .map {
                        "\(TerminalDisplay.width(of: $0)):\($0)"
                    }
                    .joined(
                        separator: " | "
                    )
            )
        }

        let groupedTimeline = TerminalTimeline(
            items: [
                TerminalTimelineItem(
                    id: Step.verify,
                    title: "swift_build",
                    state: .failed
                ),
                TerminalTimelineItem(
                    id: Step.branchRepair,
                    title: "mutate_files",
                    state: .completed,
                    groups: [
                        "on failure",
                    ]
                ),
                TerminalTimelineItem(
                    id: Step.branchBuild,
                    title: "swift_build",
                    state: .completed,
                    groups: [
                        "on failure",
                    ]
                ),
                TerminalTimelineItem(
                    id: Step.suffix,
                    title: "git_diff",
                    state: .pending
                ),
            ],
            style: .plain
        )
        let groupedLayout = groupedTimeline.layout(
            width: 24,
            selectedID: .branchRepair
        )

        guard let repairRows = groupedLayout.itemRows[.branchRepair],
              let branchBuildRows = groupedLayout.itemRows[.branchBuild],
              let suffixRows = groupedLayout.itemRows[.suffix],
              let groupHeader = groupedLayout.lines.firstIndex(
                where: {
                    $0.contains(
                        "└─ on failure"
                    )
                }
              ),
              groupHeader < repairRows.lowerBound,
              groupedLayout.lines[repairRows.lowerBound]
                .hasPrefix("   > ✓ mutate_files"),
              groupedLayout.lines[branchBuildRows.lowerBound]
                .hasPrefix("     ✓ swift_build"),
              suffixRows.lowerBound > branchBuildRows.lowerBound,
              groupedLayout.lines[suffixRows.lowerBound - 1] == "  │",
              groupedLayout.lines.allSatisfy({
                  TerminalDisplay.width(
                      of: $0
                  ) <= 24
              }) else {
            throw TerminalTestFailure(
                probe: "TerminalTimeline nested group rendering",
                expectation: "group header and nested branch rows remain non-selectable, indented, and width-stable",
                observed: groupedLayout.lines.joined(
                    separator: " | "
                )
            )
        }
    }
}
