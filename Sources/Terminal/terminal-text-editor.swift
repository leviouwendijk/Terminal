import Dispatch
import Foundation
import Swim

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
    public private(set) var selection: TerminalSelection?
    public private(set) var blockInsertSession: TerminalBlockInsertSession?
    public private(set) var replaceSession: TerminalReplaceSession?
    public private(set) var registers: TerminalRegisterBank
    public var clipboard: TerminalClipboardDestination
    public var shiftWidth: Int
    public private(set) var yankPresentation: TerminalYankPresentation?

    private var layoutCache: LayoutCache?
    private var presentationState: PresentationState?

    public init(
        text: String = "",
        cursorOffset: Int? = nil,
        mode: TerminalInteractionMode = .normal,
        visibleRows: Int = 0,
        shiftWidth: Int = 4,
        clipboard: TerminalClipboardDestination = .system,
        registers: TerminalRegisterBank = .init()
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
        self.selection = mode == .visual
            ? TerminalSelection(
                anchor: self.buffer.cursorOffset,
                cursor: self.buffer.cursorOffset,
                kind: .character
            )
            : nil
        self.blockInsertSession = nil
        self.replaceSession = mode == .replace
            ? TerminalReplaceSession(
                startOffset: self.buffer.cursorOffset
            )
            : nil
        self.registers = registers
        self.clipboard = clipboard
        self.shiftWidth = max(
            1,
            shiftWidth
        )
        self.yankPresentation = nil
        self.layoutCache = nil
        self.presentationState = nil
    }

    public static func == (
        lhs: TerminalTextEditor,
        rhs: TerminalTextEditor
    ) -> Bool {
        lhs.buffer == rhs.buffer
            && lhs.interaction == rhs.interaction
            && lhs.viewport == rhs.viewport
            && lhs.selection == rhs.selection
            && lhs.blockInsertSession == rhs.blockInsertSession
            && lhs.replaceSession == rhs.replaceSession
            && lhs.registers == rhs.registers
            && lhs.clipboard == rhs.clipboard
            && lhs.shiftWidth == rhs.shiftWidth
    }

    public func hash(
        into hasher: inout Hasher
    ) {
        hasher.combine(
            buffer
        )
        hasher.combine(
            interaction
        )
        hasher.combine(
            viewport
        )
        hasher.combine(
            selection
        )
        hasher.combine(
            blockInsertSession
        )
        hasher.combine(
            replaceSession
        )
        hasher.combine(
            registers
        )
        hasher.combine(
            clipboard
        )
        hasher.combine(
            shiftWidth
        )
    }

    public var mode: TerminalInteractionMode {
        interaction.mode
    }

    public var resolvedSelection: TerminalResolvedSelection? {
        selection?.resolved(
            in: buffer
        )
    }

    public var selectionRange: Range<Int>? {
        resolvedSelection?.contiguousRange
    }

    public var selectionRanges: [Range<Int>] {
        resolvedSelection?.sourceRanges
            ?? []
    }

    public var nextPresentationDeadlineNanoseconds: UInt64? {
        yankPresentation?.expiresAtNanoseconds
    }

    public func activeYankRanges(
        atNanoseconds now: UInt64 =
            DispatchTime.now().uptimeNanoseconds
    ) -> [Range<Int>] {
        guard let yankPresentation,
              yankPresentation.isActive(
                atNanoseconds: now
              ) else {
            return []
        }

        return yankPresentation.sourceRanges
    }

    public func activeYankRange(
        atNanoseconds now: UInt64 =
            DispatchTime.now().uptimeNanoseconds
    ) -> Range<Int>? {
        activeYankRanges(
            atNanoseconds: now
        ).first
    }

    public mutating func replace(
        with text: String,
        cursorOffset: Int? = nil
    ) {
        buffer.replace(
            with: text,
            cursorOffset: cursorOffset
        )
        selection = nil
        blockInsertSession = nil
        replaceSession = nil
        yankPresentation = nil
        presentationState = nil
    }

    public mutating func setMode(
        _ mode: TerminalInteractionMode
    ) {
        interaction.setMode(
            mode
        )
        replaceSession = mode == .replace
            ? TerminalReplaceSession(
                startOffset: buffer.cursorOffset
            )
            : nil

        if mode != .visual {
            selection = nil
        } else if selection == nil {
            selection = TerminalSelection(
                anchor: buffer.cursorOffset,
                cursor: buffer.cursorOffset,
                kind:
                    interaction.visualSelectionKind
                    ?? .character
            )
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
        yankPresentation = nil

        switch action {
        case .literal(let key):
            return handleLiteral(
                key
            )

        case .motion(let motion):
            let finalized =
                finalizeBlockInsertSession()
            let moved = handleMotion(
                motion
            )

            if moved,
               replaceSession != nil
            {
                replaceSession = TerminalReplaceSession(
                    startOffset: buffer.cursorOffset
                )
            }

            return finalized || moved
                ? .changed
                : nil

        case .command(let command):
            return handleCommand(
                command
            )

        case .enterInsert(let placement):
            blockInsertSession = nil
            replaceSession = nil
            selection = nil

            if placement == .afterCursor {
                _ = buffer.moveRight()
            }

            return .changed

        case .enterBlockInsert(let operation):
            replaceSession = nil
            return beginBlockInsert(
                operation
            )

        case .enterVisual(let kind):
            blockInsertSession = nil
            replaceSession = nil
            var selection =
                self.selection
                ?? TerminalSelection(
                    anchor: buffer.cursorOffset,
                    cursor: buffer.cursorOffset,
                    kind: kind
                )

            selection.cursor = buffer.cursorOffset
            selection.kind = kind
            selection.blockPreferredColumn =
                kind == .block
                ? TerminalBlockSelectionGeometry.position(
                    forSourceOffset: buffer.cursorOffset,
                    in: buffer
                ).column
                : nil
            self.selection = selection

            return .changed

        case .returnToNormal:
            _ = finalizeBlockInsertSession()
            replaceSession = nil
            selection = nil
            return .changed

        case .activate:
            return nil

        case .delete:
            return deleteSelectionOrCharacter()

        case .copy:
            return copySelectionOrCharacter()

        case .change:
            return changeSelection()
        }
    }

    public mutating func render(
        into frame: inout TerminalFrame,
        in region: TerminalRegion,
        isFocused: Bool = true,
        selectionStyle: TerminalStyle = .init(.inverse),
        yankStyle: TerminalStyle = .init(
            .black,
            .brightYellowBackground
        ),
        atNanoseconds now: UInt64 =
            DispatchTime.now().uptimeNanoseconds
    ) {
        guard !region.isEmpty else {
            return
        }

        let layout = layout(
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

        if let presentationState,
           presentationState.region == region {
            frame.scrollRows(
                in: region,
                by:
                    viewport.offset
                    - presentationState.offset
            )
        }

        presentationState = PresentationState(
            region: region,
            offset: viewport.offset
        )

        let visibleRows = viewport.visibleRange
        let yankRanges = activeYankRanges(
            atNanoseconds: now
        )
        let selectionRanges =
            mode == .visual
            ? self.selectionRanges
            : []

        if yankPresentation != nil,
           yankRanges.isEmpty {
            yankPresentation = nil
        }

        for visualRow in visibleRows {
            let layoutRow = layout.rows[visualRow]
            let outputRow =
                region.top
                + visualRow
                - viewport.offset

            frame.write(
                renderedContent(
                    layoutRow,
                    selectionStyle: selectionStyle,
                    selectionRanges: selectionRanges,
                    yankRanges: yankRanges,
                    yankStyle: yankStyle
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
                ),
            shape: cursorShape
        )
    }

    private var cursorShape: TerminalCursorShape {
        switch mode {
        case .insert:
            return .bar

        case .replace:
            return .underline

        case .normal,
             .visual:
            return .block
        }
    }

    private mutating func insertPastedText(
        _ text: String
    ) -> TerminalTextEditorEvent? {
        yankPresentation = nil

        if replaceSession != nil {
            return handleReplacePastedText(
                text
            )
        }

        if blockInsertSession != nil {
            return handleBlockInsertPastedText(
                text
            )
        }

        if selection?.kind == .block {
            return nil
        }

        if let selectionRange {
            _ = buffer.replace(
                selectionRange,
                with: text
            )
            selection = nil
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
        if replaceSession != nil {
            return handleReplaceLiteral(
                key
            )
        }

        if blockInsertSession != nil {
            return handleBlockInsertLiteral(
                key
            )
        }

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

    private mutating func handleReplaceLiteral(
        _ key: TerminalKey
    ) -> TerminalTextEditorEvent? {
        guard var session = replaceSession else {
            return nil
        }

        let changed: Bool

        switch key {
        case .char(let text):
            changed = session.apply(
                text,
                to: &buffer
            )

        case .space:
            changed = session.apply(
                " ",
                to: &buffer
            )

        case .tab:
            changed = session.apply(
                "\t",
                to: &buffer
            )

        case .enter:
            changed = session.apply(
                "\n",
                to: &buffer
            )

        case .backspace,
             .control("H"):
            changed = session.restoreLast(
                in: &buffer
            )

        case .delete:
            changed = buffer.deleteForward()

            if changed {
                session = TerminalReplaceSession(
                    startOffset: buffer.cursorOffset
                )
            }

        default:
            return nil
        }

        replaceSession = session

        return changed
            ? .changed
            : nil
    }

    private mutating func handleReplacePastedText(
        _ text: String
    ) -> TerminalTextEditorEvent? {
        guard var session = replaceSession else {
            return nil
        }

        let normalized = text
            .replacingOccurrences(
                of: "\r\n",
                with: "\n"
            )
            .replacingOccurrences(
                of: "\r",
                with: "\n"
            )

        guard !normalized.isEmpty else {
            return nil
        }

        var changed = false

        for character in normalized {
            changed =
                session.apply(
                    String(
                        character
                    ),
                    to: &buffer
                )
                || changed
        }

        replaceSession = session

        return changed
            ? .changed
            : nil
    }

    private mutating func handleBlockInsertLiteral(
        _ key: TerminalKey
    ) -> TerminalTextEditorEvent? {
        switch key {
        case .char(let character):
            return appendBlockInsertText(
                String(
                    character
                )
            )

        case .space:
            return appendBlockInsertText(
                " "
            )

        case .tab:
            return appendBlockInsertText(
                "\t"
            )

        case .backspace,
             .control("H"):
            guard var session = blockInsertSession,
                  !session.insertedText.isEmpty else {
                _ = finalizeBlockInsertSession()

                return buffer.deleteBackward()
                    ? .changed
                    : nil
            }

            guard buffer.deleteBackward() else {
                return nil
            }

            _ = session.removeLastCharacter()
            blockInsertSession = session
            return .changed

        case .enter:
            _ = finalizeBlockInsertSession()

            return buffer.insertNewline()
                ? .changed
                : nil

        case .delete:
            _ = finalizeBlockInsertSession()

            return buffer.deleteForward()
                ? .changed
                : nil

        default:
            return nil
        }
    }

    private mutating func handleBlockInsertPastedText(
        _ text: String
    ) -> TerminalTextEditorEvent? {
        guard !text.contains(
            "\n"
        ),
        !text.contains(
            "\r"
        ) else {
            _ = finalizeBlockInsertSession()

            return buffer.insert(
                text
            )
                ? .changed
                : nil
        }

        return appendBlockInsertText(
            text
        )
    }

    private mutating func appendBlockInsertText(
        _ text: String
    ) -> TerminalTextEditorEvent? {
        guard var session = blockInsertSession,
              !text.isEmpty,
              buffer.insert(
                text
              ) else {
            return nil
        }

        session.append(
            text
        )
        blockInsertSession = session
        return .changed
    }

    private mutating func beginBlockInsert(
        _ operation: TerminalBlockInsertOperation
    ) -> TerminalTextEditorEvent? {
        guard let selection,
              selection.kind == .block,
              let resolved = selection.resolved(
                in: buffer
              ),
              case .block(let block) = resolved,
              let firstRow = block.rows.first else {
            return nil
        }

        let registerValue =
            operation == .change
            ? TerminalRegisterValue(
                capturing: resolved,
                in: buffer
            )
            : nil
        let insertionColumn =
            operation == .insertAfter
            ? block.columns.upperBound
            : block.columns.lowerBound
        let rows = block.rows.map(
            \.row
        )

        if operation == .change {
            _ = delete(
                resolved
            )

            if let registerValue {
                registers.writeUnnamed(
                    registerValue
                )
            }
        }

        self.selection = nil
        interaction.setMode(
            .insert
        )

        guard prepareBlockInsertionCursor(
            row: firstRow.row,
            column: insertionColumn
        ) else {
            return nil
        }

        blockInsertSession = TerminalBlockInsertSession(
            operation: operation,
            rows: rows,
            insertionColumn: insertionColumn,
            primaryRow: firstRow.row
        )

        return .changed
    }

    @discardableResult
    private mutating func finalizeBlockInsertSession() -> Bool {
        guard let session = blockInsertSession else {
            return false
        }

        blockInsertSession = nil

        guard !session.insertedText.isEmpty else {
            return false
        }

        let primaryCursorOffset = buffer.cursorOffset
        let layout = TerminalBlockSelectionGeometry.layout(
            in: buffer
        )
        var insertions: [
            (
                offset: Int,
                text: String
            )
        ] = []

        for rowIndex in session.rows
        where rowIndex != session.primaryRow {
            guard layout.rows.indices.contains(
                rowIndex
            ) else {
                continue
            }

            let row = layout.rows[
                rowIndex
            ]
            let offset = blockInsertionOffset(
                atColumn: session.insertionColumn,
                in: row
            )
            let paddingCount = max(
                0,
                session.insertionColumn - row.columns
            )
            let padding = String(
                repeating: " ",
                count: paddingCount
            )

            insertions.append(
                (
                    offset: offset,
                    text:
                        padding
                        + session.insertedText
                )
            )
        }

        var changed = false

        for insertion in insertions.reversed() {
            _ = buffer.setCursor(
                offset: insertion.offset
            )

            changed =
                buffer.insert(
                    insertion.text
                )
                || changed
        }

        _ = buffer.setCursor(
            offset: primaryCursorOffset
        )

        return changed
    }

    private mutating func prepareBlockInsertionCursor(
        row rowIndex: Int,
        column: Int
    ) -> Bool {
        let layout = TerminalBlockSelectionGeometry.layout(
            in: buffer
        )

        guard layout.rows.indices.contains(
            rowIndex
        ) else {
            return false
        }

        let row = layout.rows[
            rowIndex
        ]
        let offset = blockInsertionOffset(
            atColumn: column,
            in: row
        )
        let paddingCount = max(
            0,
            column - row.columns
        )

        _ = buffer.setCursor(
            offset: offset
        )

        if paddingCount > 0 {
            _ = buffer.insert(
                String(
                    repeating: " ",
                    count: paddingCount
                )
            )
        }

        return true
    }

    private func blockInsertionOffset(
        atColumn column: Int,
        in row: TerminalTextLayoutRow
    ) -> Int {
        let offset = row.sourceOffset(
            atColumn: column
        )
        let resolvedColumn = row.column(
            atSourceOffset: offset
        )

        if resolvedColumn < column,
           offset < row.sourceRange.upperBound {
            return offset + 1
        }

        return offset
    }

    private mutating func handleCommand(
        _ command: TerminalCommand
    ) -> TerminalTextEditorEvent? {
        switch command {
        case .motion(
            let motion,
            count: let count
        ):
            return handleMotion(
                motion,
                count: count
            )
                ? .changed
                : nil

        case .operate(
            let operation,
            target: let target
        ):
            return handleOperator(
                operation,
                target: target
            )

        case .paste(
            let placement,
            count: let count
        ):
            guard let value = registers.unnamed else {
                return nil
            }

            return TerminalRegisterPaste.apply(
                value,
                placement: placement,
                count: count,
                to: &buffer
            )
                ? .changed
                : nil

        case .edit(let edit):
            return handleEdit(
                edit
            )

        case .replaceCharacters(
            let replacement,
            count: let count
        ):
            return buffer.replaceCharactersOnLine(
                count: count,
                with: replacement
            )
                ? .changed
                : nil

        case .joinLines(let count):
            return buffer.joinLines(
                count: count
            )
                ? .changed
                : nil

        case .toggleCase(let count):
            return buffer.toggleCaseOnLine(
                count: count
            )
                ? .changed
                : nil
        }
    }

    private mutating func handleEdit(
        _ edit: TerminalEditCommand
    ) -> TerminalTextEditorEvent {
        blockInsertSession = nil
        replaceSession = nil
        selection = nil

        switch edit {
        case .insertAtFirstNonWhitespace:
            _ = buffer.moveToFirstNonWhitespaceOnLine()

        case .appendAtLineEnd:
            _ = buffer.moveToLineEnd()

        case .openLineBelow:
            _ = buffer.openLineBelow()

        case .openLineAbove:
            _ = buffer.openLineAbove()

        case .enterReplaceMode:
            replaceSession = TerminalReplaceSession(
                startOffset: buffer.cursorOffset
            )
            interaction.setMode(
                .replace
            )
            return .changed
        }

        interaction.setMode(
            .insert
        )
        return .changed
    }

    private mutating func handleMotion(
        _ motion: TerminalMotion,
        count rawCount: Int = 1
    ) -> Bool {
        let count = max(
            1,
            rawCount
        )
        let changed: Bool

        if selection?.kind == .block {
            switch motion {
            case .up:
                changed = moveBlockVertically(
                    by: -count
                )

            case .down:
                changed = moveBlockVertically(
                    by: count
                )

            default:
                changed = buffer.move(
                    motion,
                    count: count,
                    pageRows: max(
                        1,
                        viewport.visibleRows - 1
                    )
                )
            }
        } else {
            changed = buffer.move(
                motion,
                count: count,
                pageRows: max(
                    1,
                    viewport.visibleRows - 1
                )
            )
        }

        if var selection {
            selection.cursor = buffer.cursorOffset

            if selection.kind == .block,
               motion != .up,
               motion != .down {
                selection.blockPreferredColumn =
                    TerminalBlockSelectionGeometry.position(
                        forSourceOffset: buffer.cursorOffset,
                        in: buffer
                    ).column
            }

            self.selection = selection
        }

        return changed
    }

    private mutating func moveBlockVertically(
        by rows: Int
    ) -> Bool {
        let layout = TerminalBlockSelectionGeometry.layout(
            in: buffer
        )
        let current = layout.position(
            forCursorOffset: buffer.cursorOffset
        )
        let preferredColumn =
            selection?.blockPreferredColumn
            ?? current.column
        let lastRow = max(
            0,
            layout.rows.count - 1
        )
        let targetRow: Int

        if rows < 0 {
            let distance = min(
                current.row,
                -rows
            )

            targetRow = current.row - distance
        } else {
            let distance = min(
                lastRow - current.row,
                rows
            )

            targetRow = current.row + distance
        }

        let targetOffset = layout.rows[
            targetRow
        ].sourceOffset(
            atColumn: preferredColumn
        )

        return buffer.move(
            toOffset: targetOffset
        )
    }

    private mutating func handleOperator(
        _ operation: TerminalOperator,
        target: TerminalCommandTarget
    ) -> TerminalTextEditorEvent? {
        if operation == .shiftLeft
            || operation == .shiftRight
        {
            guard let resolved = TerminalTextTargetResolver.resolve(
                target,
                in: buffer,
                pageRows: max(
                    1,
                    viewport.visibleRows - 1
                )
            ) else {
                return nil
            }

            let direction: TerminalIndentationShift =
                operation == .shiftRight
                ? .right
                : .left

            return buffer.shiftLines(
                in: resolved.range,
                direction: direction,
                width: shiftWidth
            )
                ? .changed
                : nil
        }

        if operation == .change,
           buffer.isEmpty,
           case .line = target
        {
            registers.writeUnnamed(
                .line(
                    ""
                )
            )
            selection = nil
            interaction.setMode(
                .insert
            )
            return .changed
        }

        guard let resolved = TerminalTextTargetResolver.resolve(
            target,
            for: operation,
            in: buffer,
            pageRows: max(
                1,
                viewport.visibleRows - 1
            )
        ) else {
            return nil
        }

        guard let registerValue = TerminalRegisterValue(
            capturing: resolved,
            in: buffer
        ) else {
            return nil
        }

        switch operation {
        case .delete:
            guard buffer.delete(
                resolved.range
            ) else {
                return nil
            }

            registers.writeUnnamed(
                registerValue
            )
            return .changed

        case .yank:
            registers.writeUnnamed(
                registerValue
            )

            return copiedEvent(
                value: registerValue,
                sourceRanges: [
                    resolved.range,
                ]
            )

        case .change:
            guard applyChange(
                resolved,
                registerValue: registerValue
            ) else {
                return nil
            }

            registers.writeUnnamed(
                registerValue
            )
            selection = nil
            interaction.setMode(
                .insert
            )
            return .changed

        case .shiftLeft,
             .shiftRight:
            return nil
        }
    }

    @discardableResult
    private mutating func applyChange(
        _ resolved: TerminalResolvedTextTarget,
        registerValue: TerminalRegisterValue
    ) -> Bool {
        switch resolved.kind {
        case .character:
            return buffer.delete(
                resolved.range
            )

        case .line:
            let lowerBound = resolved.range.lowerBound
            let replacement = registerValue.text.hasSuffix(
                "\n"
            )
                ? "\n"
                : ""
            let changed = buffer.replace(
                resolved.range,
                with: replacement
            )

            if changed {
                _ = buffer.setCursor(
                    offset: lowerBound
                )
            }

            return changed
        }
    }

    private mutating func deleteSelectionOrCharacter()
        -> TerminalTextEditorEvent?
    {
        if let selection {
            let resolved = selection.resolved(
                in: buffer
            )

            self.selection = nil
            interaction.setMode(
                .normal
            )

            guard let resolved,
                  let registerValue = TerminalRegisterValue(
                    capturing: resolved,
                    in: buffer
                  ) else {
                return .changed
            }

            guard delete(
                resolved
            ) else {
                return .changed
            }

            registers.writeUnnamed(
                registerValue
            )
            return .changed
        }

        guard buffer.cursorOffset < buffer.characterCount else {
            return nil
        }

        let range =
            buffer.cursorOffset..<(buffer.cursorOffset + 1)
        let registerValue = TerminalRegisterValue.character(
            buffer.text(
                in: range
            )
        )

        guard buffer.delete(
            range
        ) else {
            return nil
        }

        registers.writeUnnamed(
            registerValue
        )
        return .changed
    }

    @discardableResult
    private mutating func delete(
        _ selection: TerminalResolvedSelection
    ) -> Bool {
        switch selection {
        case .contiguous(let range, _):
            return buffer.delete(
                range
            )

        case .block(let block):
            var changed = false

            for range in block.sourceRanges.reversed() {
                changed =
                    buffer.delete(
                        range
                    )
                    || changed
            }

            return changed
        }
    }

    private mutating func changeSelection()
        -> TerminalTextEditorEvent?
    {
        guard let selection,
              selection.kind != .block,
              let resolved = selection.resolved(
                in: buffer
              ),
              let registerValue = TerminalRegisterValue(
                capturing: resolved,
                in: buffer
              ) else {
            return nil
        }

        guard case .contiguous(
            let range,
            let kind
        ) = resolved else {
            return nil
        }

        let changed: Bool

        switch kind {
        case .character:
            let lowerBound = range.lowerBound
            changed = buffer.delete(
                range
            )

            if changed {
                _ = buffer.setCursor(
                    offset: lowerBound
                )
            }

        case .line:
            let lowerBound = range.lowerBound
            let replacement = registerValue.text.hasSuffix(
                "\n"
            )
                ? "\n"
                : ""
            changed = buffer.replace(
                range,
                with: replacement
            )

            if changed {
                _ = buffer.setCursor(
                    offset: lowerBound
                )
            }

        case .block:
            return nil
        }

        guard changed else {
            return nil
        }

        registers.writeUnnamed(
            registerValue
        )
        self.selection = nil
        interaction.setMode(
            .insert
        )
        return .changed
    }

    private mutating func copySelectionOrCharacter()
        -> TerminalTextEditorEvent?
    {
        let resolved: TerminalResolvedSelection?

        if let selection {
            resolved = selection.resolved(
                in: buffer
            )
        } else if buffer.cursorOffset < buffer.characterCount {
            resolved = .contiguous(
                range:
                    buffer.cursorOffset..<(buffer.cursorOffset + 1),
                kind: .character
            )
        } else {
            resolved = nil
        }

        selection = nil
        interaction.setMode(
            .normal
        )

        guard let resolved,
              let registerValue = TerminalRegisterValue(
                capturing: resolved,
                in: buffer
              ) else {
            return .changed
        }

        registers.writeUnnamed(
            registerValue
        )

        return copiedEvent(
            value: registerValue,
            sourceRanges: resolved.sourceRanges
        )
    }

    private mutating func copiedEvent(
        value: TerminalRegisterValue,
        sourceRanges: [Range<Int>],
        atNanoseconds now: UInt64 =
            DispatchTime.now().uptimeNanoseconds
    ) -> TerminalTextEditorEvent {
        let text = value.text

        _ = clipboard.write(
            text
        )

        let (
            expiration,
            overflow
        ) = now.addingReportingOverflow(
            TerminalYankPresentation.standardDurationNanoseconds
        )

        yankPresentation = TerminalYankPresentation(
            sourceRanges: sourceRanges,
            expiresAtNanoseconds:
                overflow
                ? UInt64.max
                : expiration
        )

        return .copied(
            text
        )
    }

    private mutating func layout(
        columns: Int
    ) -> TerminalTextLayout {
        let columns = max(
            1,
            columns
        )

        if let layoutCache,
           layoutCache.columns == columns,
           layoutCache.text == buffer.text {
            return layoutCache.layout
        }

        let layout = TerminalTextLayout(
            text: buffer.text,
            columns: columns
        )

        layoutCache = LayoutCache(
            text: buffer.text,
            columns: columns,
            layout: layout
        )

        return layout
    }

    private func renderedContent(
        _ row: TerminalTextLayoutRow,
        selectionStyle: TerminalStyle,
        selectionRanges: [Range<Int>],
        yankRanges: [Range<Int>],
        yankStyle: TerminalStyle
    ) -> String {
        if let yankRange = yankRanges.first(
            where: {
                row.sourceRange.overlaps(
                    $0
                )
            }
        ) {
            return renderedContent(
                row,
                sourceRange: yankRange,
                style: yankStyle
            )
        }

        guard mode == .visual,
              let selectionRange = selectionRanges.first(
                where: {
                    row.sourceRange.overlaps(
                        $0
                    )
                }
              ) else {
            return row.content
        }

        return renderedContent(
            row,
            sourceRange: selectionRange,
            style: selectionStyle
        )
    }

    private func renderedContent(
        _ row: TerminalTextLayoutRow,
        sourceRange: Range<Int>,
        style: TerminalStyle
    ) -> String {
        let lower = max(
            row.sourceRange.lowerBound,
            sourceRange.lowerBound
        )
        let upper = min(
            row.sourceRange.upperBound,
            sourceRange.upperBound
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
            + style.apply(
                selected
            )
            + after
    }

    private struct PresentationState:
        Sendable
    {
        var region: TerminalRegion
        var offset: Int
    }

    private struct LayoutCache:
        Sendable
    {
        var text: String
        var columns: Int
        var layout: TerminalTextLayout
    }
}
