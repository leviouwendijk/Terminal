public enum TerminalChoiceResult<
    ID: Hashable & Sendable
>:
    Sendable
{
    case picked(ID)

    case cancelled(
        current: ID?
    )

    public var currentID: ID? {
        switch self {
        case .picked(
            let id
        ):
            return id

        case .cancelled(
            let current
        ):
            return current
        }
    }

    public var pickedID: ID? {
        switch self {
        case .picked(
            let id
        ):
            return id

        case .cancelled:
            return nil
        }
    }
}

public extension Terminal {
    static func choose<
        ID: Hashable & Sendable
    >(
        _ title: String,
        choices: [TerminalMenuItem<ID>],
        default defaultID: ID? = nil,
        instructions: String =
            TerminalNavigationDefaults.verticalInstructions,
        stream: TerminalStream = .standardError
    ) throws -> ID? {
        try chooseResult(
            title,
            choices: choices,
            default: defaultID,
            instructions: instructions,
            stream: stream
        )
        .pickedID
    }

    static func chooseResult<
        ID: Hashable & Sendable
    >(
        _ title: String,
        choices: [TerminalMenuItem<ID>],
        default defaultID: ID? = nil,
        instructions: String =
            TerminalNavigationDefaults.verticalInstructions,
        stream: TerminalStream = .standardError
    ) throws -> TerminalChoiceResult<ID> {
        let enabled = choices.filter(
            \.isEnabled
        )

        guard let firstEnabled = enabled.first else {
            return .cancelled(
                current: nil
            )
        }

        let resolvedDefault: ID

        if let defaultID,
           enabled.contains(
            where: {
                $0.id == defaultID
            }
           ) {
            resolvedDefault = defaultID
        } else {
            resolvedDefault = firstEnabled.id
        }

        guard isInteractive else {
            let selected = chooseLineFallback(
                title,
                choices: enabled,
                default: resolvedDefault,
                stream: stream
            )

            if let selected {
                return .picked(
                    selected
                )
            }

            return .cancelled(
                current: resolvedDefault
            )
        }

        let menu = TerminalInteractiveMenu<
            TerminalMenuItem<ID>,
            ID
        >(
            items: choices,
            configuration: .inline(
                title: title,
                instructions: instructions,
                wrapMode: .wrap,
                outputStream: stream,
                completionPresentation: .clear,
                currentRowStyle: .inverse
            ),
            id: {
                $0.id
            },
            isEnabled: {
                $0.isEnabled
            },
            row: { row in
                row.item.rowContent.render(
                    isCurrent: row.isCurrent,
                    isEnabled: row.isEnabled,
                    theme: .standard,
                    width: Terminal.size(
                        for: stream
                    ).columns
                )
            }
        )

        switch try menu.runRetainingState(
            initialID: resolvedDefault
        ) {
        case .picked(
            _,
            let id
        ):
            return .picked(
                id
            )

        case .cancelled(
            _,
            let currentID
        ):
            return .cancelled(
                current: currentID
            )
        }
    }

    private static func chooseLineFallback<
        ID: Hashable & Sendable
    >(
        _ title: String,
        choices: [TerminalMenuItem<ID>],
        default defaultID: ID,
        stream: TerminalStream
    ) -> ID? {
        let indexed = choices.enumerated()
            .map { index, item in
                (
                    key: String(index + 1),
                    item: item
                )
            }

        let lineChoices = indexed.map {
            TerminalLineChoice(
                key: $0.key,
                title: $0.item.title,
                detail: $0.item.caption
            )
        }

        let defaultKey = indexed.first {
            $0.item.id == defaultID
        }?.key

        guard let selected = chooseLine(
            title,
            choices: lineChoices,
            default: defaultKey,
            stream: stream
        ) else {
            return nil
        }

        return indexed.first {
            $0.key == selected.key
        }?.item.id
    }
}
