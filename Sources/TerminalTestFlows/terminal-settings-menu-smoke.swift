import Terminal

enum TerminalSettingsMenuSmoke {
    enum RowID:
        String,
        Sendable,
        Hashable
    {
        case model
        case exposure
        case skills
        case discovery
        case all
        case explicit
    }

    enum Failure: Error {
        case initialSelection
        case navigation
        case toggle
        case unavailable
        case cancel
        case selection
        case presentation
        case breadcrumb
    }

    static func run() throws {
        var control = TerminalSettingsMenuControl(
            title: "Conversation settings",
            rows: rootRows,
            currentID: .model,
            instructions: "j/k move  enter open  q close"
        )

        guard control.currentID == .model else {
            throw Failure.initialSelection
        }

        guard control.handle(
            .down
        ) == .currentChanged(
            .exposure
        ),
              control.currentID == .exposure
        else {
            throw Failure.navigation
        }

        guard control.handle(
            .char("h")
        ) == .cancelRequested else {
            throw Failure.cancel
        }

        guard control.select(
            id: .skills
        ),
              control.currentID == .skills,
              control.handle(
                .space
              ) == .toggled(
                .skills
              )
        else {
            throw Failure.toggle
        }

        control.update(
            path: [
                "Tool exposure",
            ],
            rows: exposureRows,
            preservingCurrent: false,
            instructions: "j/k move  enter select  q back"
        )

        guard control.breadcrumb
            == "Conversation settings / Tool exposure" else {
            throw Failure.breadcrumb
        }

        guard control.handle(
            .enter
        ) == .accepted(
            .discovery
        ) else {
            throw Failure.selection
        }

        guard control.select(
            id: .explicit
        ),
              control.handle(
                .enter
              ) == .unavailable(
                .explicit
              )
        else {
            throw Failure.unavailable
        }

        var frame = TerminalFrame(
            rows: 28,
            columns: 100
        )
        control.render(
            into: &frame,
            in: TerminalRegion(
                rows: 28,
                columns: 100
            ),
            theme: .agentic
        )

        let presentation = stripANSI(
            frame.resolved().spans
                .map(\.content)
                .joined(
                    separator: "\n"
                )
        )

        guard presentation.contains(
            "Conversation settings / Tool exposure"
        ),
              presentation.contains(
                "Discovery"
              ),
              presentation.contains(
                "All tools"
              ),
              presentation.contains(
                "Explicit"
              ),
              presentation.contains(
                "initial tools"
              ),
              presentation.contains(
                "find_tools"
              )
        else {
            throw Failure.presentation
        }

        print(
            "terminal settings menu smoke passed"
        )
    }
}

private extension TerminalSettingsMenuSmoke {
    static var rootRows: [
        TerminalSettingsRow<RowID>
    ] {
        [
            TerminalSettingsRow(
                id: .model,
                title: "Model",
                value: "Claude Sonnet 4.6",
                accessory: .disclosure,
                detail: TerminalSettingsDetail(
                    title: "Claude Sonnet 4.6",
                    fields: [
                        TerminalField(
                            "provider",
                            "AWS Bedrock"
                        ),
                    ],
                    body: "Model selection applies to the next submission."
                )
            ),
            TerminalSettingsRow(
                id: .exposure,
                title: "Tool exposure",
                value: "Discovery",
                accessory: .disclosure,
                detail: TerminalSettingsDetail(
                    title: "Discovery",
                    fields: [
                        TerminalField(
                            "initial tools",
                            "find_tools"
                        ),
                    ],
                    body: "Capabilities can be activated as they are discovered."
                )
            ),
            TerminalSettingsRow(
                id: .skills,
                title: "Skills",
                value: "None",
                accessory: .disclosure,
                detail: TerminalSettingsDetail(
                    title: "Skills",
                    body: "No skills are selected."
                )
            ),
        ]
    }

    static var exposureRows: [
        TerminalSettingsRow<RowID>
    ] {
        [
            TerminalSettingsRow(
                id: .discovery,
                title: "Discovery",
                accessory: .radio(
                    selected: true
                ),
                detail: TerminalSettingsDetail(
                    title: "Discovery",
                    fields: [
                        TerminalField(
                            "initial tools",
                            "find_tools"
                        ),
                        TerminalField(
                            "dynamic",
                            "yes"
                        ),
                    ],
                    body: "Start small and activate capabilities as they are discovered."
                )
            ),
            TerminalSettingsRow(
                id: .all,
                title: "All tools",
                accessory: .radio(
                    selected: false
                ),
                detail: TerminalSettingsDetail(
                    title: "All tools",
                    body: "Advertise every model-facing tool immediately."
                )
            ),
            TerminalSettingsRow(
                id: .explicit,
                title: "Explicit",
                caption: "Requires an explicit tool picker.",
                isEnabled: false,
                accessory: .radio(
                    selected: false
                ),
                detail: TerminalSettingsDetail(
                    title: "Explicit",
                    body: "A fixed tool set can be configured once an explicit tool-selection surface is installed."
                )
            ),
        ]
    }
}
