import Foundation

public enum TerminalTextEditorEvent:
    Sendable,
    Hashable
{
    case changed
    case copied(String)
    case cancelRequested
}

public struct TerminalTextEditor:
    Sendable,
    Hashable
{
    public private(set) var buffer: TerminalTextBuffer
    public private(set) var interaction: TerminalModalInteraction
    public private(set) var viewport: TerminalViewport
    public private(set) var selectionAnchor: Int?

    public init(
        text: String = "",
        cursorOffset: Int? = nil,
        mode: TerminalInteractionMode = .normal,
        visibleRows: Int = 0
    ) {
        self.buffer = TerminalTextBuffer(
            text: text,
            cursorOffset: cursorOffset
        )
        self.interaction = TerminalModalInteraction(
            mode: mode
        )
        self.viewport = TerminalViewport(
            visibleRows: visibleRows
        )
        self.selectionAnchor = nil
    }

    public var mode: TerminalInteractionMode {
        interaction.mode
    }

    public var selectionRange: Range<Int>? {
        guard let selectionAnchor else {
            return nil
        }

        let cursor = buffer.cursorOffset
        let lower = min(
            selectionAnchor,
            cursor
        )
        let upper = max(
            selectionAnchor,
            cursor
        )

        if lower == upper {
            guard lower < buffer.characterCount else {
                return nil
            }

            return lower..<(lower + 1)
        }

        return lower..<min(
            buffer.characterCount,
            upper + 1
        )
    }

    public mutating func replace(
        with text: String,
        cursorOffset: Int? = nil
    ) {
        buffer.replace(
            with: text,
            cursorOffset: cursorOffset
        )
        selectionAnchor = nil
    }

    public mutating func setMode(
        _ mode: TerminalInteractionMode
    ) {
        interaction.setMode(
            mode
        )

        if mode != .visual {
            selectionAnchor = nil
        } else if selectionAnchor == nil {
            selectionAnchor = buffer.cursorOffset
        }
    }

    public mutating func handle(
        _ event: TerminalInputEvent
    ) -> TerminalTextEditorEvent? {
        switch event {
        case .key(let key):
            return handle(
                key
            )

        case .paste(let text):
            return insertPastedText(
                text
            )
        }
    }

    public mutating func handle(
        _ key: TerminalKey
    ) -> TerminalTextEditorEvent? {
        switch interaction.handle(
            key
        ) {
        case .consumed:
            return nil

        case .unhandled:
            return key == .escape
                ? .cancelRequested
                : nil

        case .action(let action):
            return handle(
                action
            )
        }
    }

    @discardableResult
    public mutating func handle(
        _ action: TerminalInteractionAction
    ) -> TerminalTextEditorEvent? {
        switch action {
        case .literal(let key):
            return handleLiteral(
                key
            )

        case .motion(let motion):
            return handleMotion(
                motion
            )
                ? .changed
                : nil

        case .enterInsert(let placement):
            selectionAnchor = nil

            if placement == .afterCursor {
                _ = buffer.moveRight()
            }

            return .changed

        case .enterVisual:
            selectionAnchor = buffer.cursorOffset
            return .changed

        case .returnToNormal:
            selectionAnchor = nil
            return .changed

        case .activate:
            return nil

        case .delete:
            return deleteSelectionOrCharacter()

        case .copy:
            return copySelectionOrCharacter()
        }
    }

    public mutating func render(
        into frame: inout TerminalFrame,
        in region: TerminalRegion,
        isFocused: Bool = true,
        selectionStyle: TerminalStyle = .init(.inverse)
    ) {
        guard !region.isEmpty else {
            return
        }

        let layout = TerminalTextLayout(
            text: buffer.text,
            columns: region.columns
        )
        let cursor = layout.position(
            forCursorOffset: buffer.cursorOffset
        )

        viewport.update(
            contentRows: layout.rows.count,
            visibleRows: region.rows
        )
        viewport.reveal(
            row: cursor.row,
            margin: min(
                1,
                max(
                    0,
                    region.rows - 1
                )
            )
        )

        let visibleRows = viewport.visibleRange

        for visualRow in visibleRows {
            let layoutRow = layout.rows[visualRow]
            let outputRow =
                region.top
                + visualRow
                - viewport.offset

            frame.write(
                renderedContent(
                    layoutRow,
                    selectionStyle: selectionStyle
                ),
                in: TerminalRegion(
                    top: outputRow,
                    leading: region.leading,
                    rows: 1,
                    columns: region.columns
                )
            )
        }

        guard isFocused,
              visibleRows.contains(
                cursor.row
              ) else {
            return
        }

        frame.placeCursor(
            row:
                region.top
                + cursor.row
                - viewport.offset,
            column:
                region.leading
                + min(
                    cursor.column,
                    max(
                        0,
                        region.columns - 1
                    )
                )
        )
    }

    private mutating func insertPastedText(
        _ text: String
    ) -> TerminalTextEditorEvent? {
        if let selectionRange {
            _ = buffer.replace(
                selectionRange,
                with: text
            )
            selectionAnchor = nil
            interaction.setMode(
                .insert
            )
            return .changed
        }

        return buffer.insert(
            text
        )
            ? .changed
            : nil
    }

    private mutating func handleLiteral(
        _ key: TerminalKey
    ) -> TerminalTextEditorEvent? {
        let changed: Bool

        switch key {
        case .char(let text):
            changed = buffer.insert(
                text
            )

        case .space:
            changed = buffer.insert(
                " "
            )

        case .tab:
            changed = buffer.insert(
                "\t"
            )

        case .enter:
            changed = buffer.insertNewline()

        case .backspace,
             .control("H"):
            changed = buffer.deleteBackward()

        case .delete:
            changed = buffer.deleteForward()

        default:
            return nil
        }

        return changed
            ? .changed
            : nil
    }

    private mutating func handleMotion(
        _ motion: TerminalMotion
    ) -> Bool {
        switch motion {
        case .left:
            return buffer.moveLeft()

        case .right:
            return buffer.moveRight()

        case .up:
            return buffer.moveUp()

        case .down:
            return buffer.moveDown()

        case .wordBackward:
            return buffer.moveWordBackward()

        case .wordForward:
            return buffer.moveWordForward()

        case .wordEnd:
            return buffer.moveToWordEnd()

        case .lineStart:
            return buffer.moveToLineStart()

        case .lineEnd:
            return buffer.moveToLineEnd()

        case .documentStart:
            return buffer.moveToDocumentStart()

        case .documentEnd:
            return buffer.moveToDocumentEnd()

        case .pageUp:
            return buffer.moveUp(
                by: max(
                    1,
                    viewport.visibleRows - 1
                )
            )

        case .pageDown:
            return buffer.moveDown(
                by: max(
                    1,
                    viewport.visibleRows - 1
                )
            )
        }
    }

    private mutating func deleteSelectionOrCharacter()
        -> TerminalTextEditorEvent?
    {
        let changed: Bool

        if let selectionRange {
            changed = buffer.delete(
                selectionRange
            )
            selectionAnchor = nil
            interaction.setMode(
                .normal
            )
        } else {
            changed = buffer.deleteForward()
        }

        return changed
            ? .changed
            : nil
    }

    private mutating func copySelectionOrCharacter()
        -> TerminalTextEditorEvent?
    {
        let range: Range<Int>?

        if let selectionRange {
            range = selectionRange
        } else if buffer.cursorOffset < buffer.characterCount {
            range = buffer.cursorOffset..<(buffer.cursorOffset + 1)
        } else {
            range = nil
        }

        selectionAnchor = nil
        interaction.setMode(
            .normal
        )

        guard let range else {
            return .changed
        }

        return .copied(
            buffer.text(
                in: range
            )
        )
    }

    private func renderedContent(
        _ row: TerminalTextLayoutRow,
        selectionStyle: TerminalStyle
    ) -> String {
        guard mode == .visual,
              let selectionRange,
              row.sourceRange.overlaps(
                selectionRange
              ) else {
            return row.content
        }

        let lower = max(
            row.sourceRange.lowerBound,
            selectionRange.lowerBound
        )
        let upper = min(
            row.sourceRange.upperBound,
            selectionRange.upperBound
        )
        let selectedStart = row.column(
            atSourceOffset: lower
        )
        let selectedEnd = row.column(
            atSourceOffset: upper
        )
        let before = selectedStart > 0
            ? TerminalDisplay.slice(
                row.content,
                columns: 0..<selectedStart
            )
            : ""
        let selected = selectedEnd > selectedStart
            ? TerminalDisplay.slice(
                row.content,
                columns: selectedStart..<selectedEnd
            )
            : ""
        let after = selectedEnd < row.columns
            ? TerminalDisplay.slice(
                row.content,
                columns: selectedEnd..<row.columns
            )
            : ""

        return before
            + selectionStyle.apply(
                selected
            )
            + after
    }
}
