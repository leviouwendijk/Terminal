import Terminal

enum TerminalMultiSelectControlSmoke {
    private struct Item: Sendable {
        let id: String
        let enabled: Bool
    }

    static func run() throws {
        var control = TerminalMultiSelectControl(
            items: [
                Item(id: "one", enabled: true),
                Item(id: "two", enabled: true),
                Item(id: "disabled", enabled: false),
                Item(id: "three", enabled: true),
            ],
            currentID: "one",
            selectedIDs: [
                "two",
            ],
            id: \.id,
            isEnabled: \.enabled
        )

        try expect(
            control.currentID == "one",
            expectation: "initial current id is one",
            observed: String(describing: control.currentID)
        )
        try expect(
            control.selectedIDs == ["two"],
            expectation: "initial selection contains two",
            observed: String(describing: control.selectedIDs)
        )

        guard case .selectionChanged(let selected)? = control.handle(.space) else {
            throw failure(
                expectation: "space toggles the current item",
                observed: "no selection event"
            )
        }
        try expect(
            selected == ["one", "two"],
            expectation: "selection follows item order after toggle",
            observed: String(describing: selected)
        )

        _ = control.handle(.down)
        try expect(
            control.currentID == "two",
            expectation: "down moves to two",
            observed: String(describing: control.currentID)
        )

        _ = control.handle(.down)
        try expect(
            control.currentID == "three",
            expectation: "navigation skips disabled rows",
            observed: String(describing: control.currentID)
        )

        _ = control.handle(.space)
        try expect(
            control.selectedIDs == ["one", "two", "three"],
            expectation: "third enabled item can be selected",
            observed: String(describing: control.selectedIDs)
        )

        control.updateItems(
            [
                Item(id: "three", enabled: true),
                Item(id: "one", enabled: true),
                Item(id: "disabled", enabled: false),
            ]
        )

        try expect(
            control.currentID == "three",
            expectation: "current id survives item refresh",
            observed: String(describing: control.currentID)
        )
        try expect(
            control.selectedIDs == ["three", "one"],
            expectation: "selection survives by id, prunes removed values, and follows refreshed item order",
            observed: String(describing: control.selectedIDs)
        )

        guard case .accepted(let accepted)? = control.handle(.enter) else {
            throw failure(
                expectation: "enter accepts the current selected id set",
                observed: "no accepted event"
            )
        }
        try expect(
            accepted == ["three", "one"],
            expectation: "accepted ids are deterministic in item order",
            observed: String(describing: accepted)
        )

        print("terminal multi-select state smoke passed")
    }

    private static func expect(
        _ condition: Bool,
        expectation: String,
        observed: String
    ) throws {
        guard condition else {
            throw failure(
                expectation: expectation,
                observed: observed
            )
        }
    }

    private static func failure(
        expectation: String,
        observed: String
    ) -> TerminalTestFailure {
        TerminalTestFailure(
            probe: "multi-select-state",
            expectation: expectation,
            observed: observed
        )
    }
}
