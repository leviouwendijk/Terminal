import Terminal

enum TerminalOverlayFoundationSmoke {
    enum Failure:
        Error
    {
        case unexpectedFocusRestoration
        case unexpectedCenteredRegion
        case unexpectedTrailingRegion
        case unexpectedComposition
    }

    private enum Focus:
        Sendable,
        Hashable
    {
        case base
        case modal
        case sheet
    }

    static func run() throws {
        try runFocusProbe()
        try runGeometryProbe()
        try runCompositionProbe()
    }

    private static func runFocusProbe() throws {
        var focus = TerminalFocusStack(
            Focus.base
        )

        focus.push(
            .modal
        )
        focus.push(
            .sheet
        )

        guard focus.current == .sheet,
              focus.depth == 2 else {
            throw Failure.unexpectedFocusRestoration
        }

        _ = focus.pop()

        guard focus.current == .modal,
              focus.depth == 1 else {
            throw Failure.unexpectedFocusRestoration
        }

        _ = focus.pop()

        guard focus.current == .base,
              focus.depth == 0 else {
            throw Failure.unexpectedFocusRestoration
        }
    }

    private static func runGeometryProbe() throws {
        let root = TerminalRegion(
            rows: 20,
            columns: 100
        )
        let centered = TerminalOverlay(
            placement: .centered(
                columns: 40,
                rows: 10
            )
        ).region(
            in: root
        )

        guard centered == TerminalRegion(
            top: 5,
            leading: 30,
            rows: 10,
            columns: 40
        ) else {
            throw Failure.unexpectedCenteredRegion
        }

        let trailing = TerminalOverlay(
            placement: .trailing(
                columns: 30
            ),
            outerInsets: TerminalInsets(
                vertical: 1,
                horizontal: 2
            )
        ).region(
            in: root
        )

        guard trailing == TerminalRegion(
            top: 1,
            leading: 68,
            rows: 18,
            columns: 30
        ) else {
            throw Failure.unexpectedTrailingRegion
        }
    }

    private static func runCompositionProbe() throws {
        var frame = TerminalFrame(
            rows: 12,
            columns: 40
        )
        let root = TerminalRegion(
            rows: 12,
            columns: 40
        )

        frame.write(
            "underlying shell",
            in: root
        )

        let overlay = TerminalOverlay(
            placement: .centered(
                columns: 20,
                rows: 8
            )
        )
        let region = overlay.region(
            in: root
        )

        _ = overlay.render(
            into: &frame,
            in: root,
            title: "overlay"
        )

        guard frame.spans(
            inRow: region.top
        ).last?.leading == region.leading else {
            throw Failure.unexpectedComposition
        }
    }
}
