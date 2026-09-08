import Swim
import Terminal

enum TerminalTextSurfaceLab {
    static func run() throws {
        let stream = TerminalStream.standardError
        let session = try TerminalSession(
            options: TerminalSession.Options(
                useAlternateScreen: true,
                hideCursor: true,
                useRawMode: true,
                useBracketedPaste: true,
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
        var surface = TerminalTextSurface(
            editor: TerminalTextEditor(
                mode: .insert
            ),
            sizePolicy: TerminalTextSurfaceSizePolicy(
                minimumRows: 1,
                maximumRows: 6
            ),
            expandedEditorPresentation: TerminalTextEditorPresentation(
                lineNumbers: .hybrid,
                indentationGuides: TerminalIndentationGuideOptions(
                    isEnabled: true,
                    width: 4,
                    glyph: "│"
                )
            ),
            placeholder: "type here..."
        )
        var size = Terminal.size(
            for: stream
        )

        func renderCurrent() {
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

            switch surface.presentation {
            case .compact:
                let statusRows = min(
                    2,
                    root.rows
                )
                let contentColumns = max(
                    1,
                    root.columns - 2
                )
                let surfaceRows = surface.resolvedRows(
                    columns: contentColumns,
                    availableRows: max(
                        0,
                        root.rows - statusRows
                    )
                )
                let surfaceTop = max(
                    root.top,
                    root.bottom - statusRows - surfaceRows
                )

                if surfaceRows > 0 {
                    frame.write(
                        "> ",
                        in: TerminalRegion(
                            top: surfaceTop,
                            leading: root.leading,
                            rows: 1,
                            columns: min(
                                2,
                                root.columns
                            )
                        )
                    )

                    surface.render(
                        into: &frame,
                        in: TerminalRegion(
                            top: surfaceTop,
                            leading: root.leading + min(
                                2,
                                root.columns
                            ),
                            rows: surfaceRows,
                            columns: contentColumns
                        ),
                        isFocused: true
                    )
                }

                if root.rows >= 2 {
                    frame.write(
                        TerminalStyle.dim.apply(
                            "mode \(surface.mode) · wrapped \(surface.contentRowCount(columns: contentColumns)) · visible \(surfaceRows)"
                        ),
                        in: TerminalRegion(
                            top: root.bottom - 2,
                            leading: root.leading,
                            rows: 1,
                            columns: root.columns
                        )
                    )
                }

                if root.rows >= 1 {
                    frame.write(
                        TerminalStyle.dim.apply(
                            "esc normal · i insert · ctrl-f expand · ctrl-c exit"
                        ),
                        in: TerminalRegion(
                            top: root.bottom - 1,
                            leading: root.leading,
                            rows: 1,
                            columns: root.columns
                        )
                    )
                }

            case .expanded:
                let overlay = TerminalOverlay(
                    placement: .centered(
                        columns: max(
                            0,
                            size.columns - 4
                        ),
                        rows: max(
                            0,
                            size.rows - 2
                        )
                    ),
                    contentInsets: TerminalInsets(
                        vertical: 0,
                        horizontal: 1
                    )
                )
                let content = overlay.render(
                    into: &frame,
                    in: TerminalRegion(
                        rows: size.rows,
                        columns: size.columns
                    ),
                    title: "text surface"
                )
                let editorRows = max(
                    0,
                    content.rows - 1
                )

                if editorRows > 0 {
                    surface.render(
                        into: &frame,
                        in: TerminalRegion(
                            top: content.top,
                            leading: content.leading,
                            rows: editorRows,
                            columns: content.columns
                        ),
                        isFocused: true
                    )
                }

                if content.rows > 0 {
                    frame.write(
                        TerminalStyle.dim.apply(
                            "mode \(surface.mode) · ctrl-f compact · ctrl-c exit"
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

            renderer.render(
                frame
            )
        }

        renderCurrent()

        while true {
            let events = reader.readEvents(
                timeoutMilliseconds: 100,
                maximumCount: 128
            )

            if events.isEmpty {
                let currentSize = Terminal.size(
                    for: stream
                )

                if currentSize != size {
                    size = currentSize
                    renderCurrent()
                }

                continue
            }

            for event in events {
                if case .key(let key) = event {
                    if key == .control("C") {
                        return
                    }

                    if key == .control("F") {
                        surface.togglePresentation()
                        continue
                    }
                }

                _ = surface.handle(
                    event
                )
            }

            size = Terminal.size(
                for: stream
            )
            renderCurrent()
        }
    }
}
