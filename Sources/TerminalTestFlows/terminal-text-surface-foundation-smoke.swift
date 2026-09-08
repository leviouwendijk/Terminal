import Swim
import Terminal

enum TerminalTextSurfaceFoundationSmoke {
    static func run() throws {
        var surface = TerminalTextSurface(
            editor: TerminalTextEditor(
                mode: .insert
            ),
            sizePolicy: TerminalTextSurfaceSizePolicy(
                minimumRows: 1,
                maximumRows: 3
            ),
            expandedEditorPresentation: TerminalTextEditorPresentation(
                lineNumbers: .hybrid,
                indentationGuides: TerminalIndentationGuideOptions(
                    isEnabled: true
                )
            )
        )

        guard surface.compactRows(
            columns: 4
        ) == 1 else {
            throw TerminalTestFailure(
                probe: "text surface empty compact height",
                expectation: "1 row",
                observed: "\(surface.compactRows(columns: 4)) rows"
            )
        }

        surface.replace(
            with: "abcdefghij",
            cursorOffset: 10
        )

        guard surface.contentRowCount(
            columns: 4
        ) == 3,
        surface.compactRows(
            columns: 4
        ) == 3 else {
            throw TerminalTestFailure(
                probe: "text surface wrapped growth",
                expectation: "3 wrapped rows and compact height 3",
                observed: "content=\(surface.contentRowCount(columns: 4)) compact=\(surface.compactRows(columns: 4))"
            )
        }

        surface.replace(
            with: "abcdefghijklmnopqrst",
            cursorOffset: 20
        )

        guard surface.contentRowCount(
            columns: 4
        ) == 5,
        surface.compactRows(
            columns: 4
        ) == 3 else {
            throw TerminalTestFailure(
                probe: "text surface compact row cap",
                expectation: "5 wrapped rows capped to 3 visible rows",
                observed: "content=\(surface.contentRowCount(columns: 4)) compact=\(surface.compactRows(columns: 4))"
            )
        }

        var frame = TerminalFrame(
            rows: 3,
            columns: 4
        )

        surface.render(
            into: &frame,
            in: TerminalRegion(
                rows: 3,
                columns: 4
            )
        )

        guard surface.viewport.visibleRows == 3,
              surface.viewport.contentRows == 5,
              surface.viewport.offset == 2 else {
            throw TerminalTestFailure(
                probe: "text surface compact cursor-follow viewport",
                expectation: "visibleRows=3 contentRows=5 offset=2",
                observed: "visibleRows=\(surface.viewport.visibleRows) contentRows=\(surface.viewport.contentRows) offset=\(surface.viewport.offset)"
            )
        }

        surface.setPresentation(
            .expanded
        )

        guard surface.editorPresentation.lineNumbers == .hybrid,
              surface.editorPresentation.indentationGuides.isEnabled else {
            throw TerminalTestFailure(
                probe: "text surface expanded editor presentation",
                expectation: "hybrid line numbers and indentation guides",
                observed: String(
                    describing: surface.editorPresentation
                )
            )
        }

        guard surface.resolvedRows(
            columns: 4,
            availableRows: 8
        ) == 8 else {
            throw TerminalTestFailure(
                probe: "text surface expanded height",
                expectation: "8 available rows",
                observed: "\(surface.resolvedRows(columns: 4, availableRows: 8)) rows"
            )
        }

        surface.setPresentation(
            .compact
        )

        guard surface.editorPresentation.lineNumbers == .hidden,
              !surface.editorPresentation.indentationGuides.isEnabled else {
            throw TerminalTestFailure(
                probe: "text surface compact editor presentation",
                expectation: "plain compact editor presentation",
                observed: String(
                    describing: surface.editorPresentation
                )
            )
        }

        guard surface.text == "abcdefghijklmnopqrst",
              surface.mode == .insert else {
            throw TerminalTestFailure(
                probe: "text surface presentation preserves editor state",
                expectation: "same text and insert mode",
                observed: "text=\(surface.text) mode=\(surface.mode)"
            )
        }
    }
}
