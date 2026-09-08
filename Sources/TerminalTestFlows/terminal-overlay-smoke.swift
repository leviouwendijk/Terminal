import Difference
import Foundation
import Swim
import Terminal

private enum TerminalOverlaySmokeFocus:
    Sendable,
    Hashable
{
    case base
    case transcript
    case navigation
    case timeline
    case messageInspector
    case approval
    case inspector
    case composerSheet
    case editor
    case quitConfirmation
}

private enum TerminalOverlaySmokeKeyAction:
    Sendable
{
    case submit
}

private enum TerminalOverlaySmokeQuitChoice:
    Sendable,
    Hashable
{
    case cancel
    case quit

    var title: String {
        switch self {
        case .cancel:
            return "Cancel"

        case .quit:
            return "Quit"
        }
    }
}

private enum TerminalOverlaySmokeDestination:
    CaseIterable,
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

private struct TerminalOverlaySmokePaste:
    Sendable,
    Hashable
{
    var buffer: TerminalTextBufferSession

    init(
        _ text: String
    ) {
        self.buffer = TerminalTextBufferSession(
            text: text
        )
    }

    var id: TerminalInputBufferID {
        buffer.id
    }

    var text: String {
        buffer.text
    }

    var lineCount: Int {
        text.reduce(
            1
        ) {
            count,
            character in

            count + (character == "\n" ? 1 : 0)
        }
    }

    var summary: String {
        let label = lineCount == 1
            ? "line"
            : "lines"

        return "\(lineCount) \(label) pasted"
    }
}

private enum TerminalOverlaySmokeContent:
    Sendable,
    Hashable
{
    case pastedText(TerminalOverlaySmokePaste)

    var summary: String {
        switch self {
        case .pastedText(let paste):
            return "paste · \(paste.summary)"
        }
    }

    var pastedTextValue: TerminalOverlaySmokePaste? {
        switch self {
        case .pastedText(let paste):
            return paste
        }
    }

    func renderedLines(
        width: Int
    ) -> [String] {
        switch self {
        case .pastedText(let paste):
            return TerminalTextLayout(
                text: paste.text,
                columns: max(
                    1,
                    width
                )
            ).rows.map(\.content)
        }
    }
}

private enum TerminalOverlaySmokeTimelineStep:
    CaseIterable,
    Sendable,
    Hashable
{
    case mutateFiles
    case swiftBuild
    case artest
    case verifyBuild
    case gitDiff

    var title: String {
        switch self {
        case .mutateFiles:
            return "mutate_files"

        case .swiftBuild,
             .verifyBuild:
            return "swift_build"

        case .artest:
            return "artest"

        case .gitDiff:
            return "git_diff"
        }
    }

    var detail: String? {
        switch self {
        case .mutateFiles:
            return "Terminal/Sources/Terminal/terminal-timeline.swift"

        case .swiftBuild:
            return "Terminal"

        case .artest:
            return "current"

        case .verifyBuild:
            return "Terminal verification"

        case .gitDiff:
            return "working tree"
        }
    }

    var state: TerminalTimelineItemState {
        switch self {
        case .mutateFiles,
             .swiftBuild:
            return .completed

        case .artest:
            return .active

        case .verifyBuild,
             .gitDiff:
            return .pending
        }
    }

    var stateLabel: String {
        switch state {
        case .pending:
            return "pending"

        case .active:
            return "active"

        case .completed:
            return "completed"

        case .warning:
            return "warning"

        case .failed:
            return "failed"

        case .skipped:
            return "skipped"
        }
    }

    var timelineItem: TerminalTimelineItem<Self> {
        TerminalTimelineItem(
            id: self,
            title: title,
            detail: detail,
            state: state
        )
    }
}

private enum TerminalOverlaySmokeInspector:
    Sendable,
    Hashable
{
    case details
    case difference
    case timelineStep(TerminalOverlaySmokeTimelineStep)

    var title: String {
        switch self {
        case .details:
            return "tool details"

        case .difference:
            return "staged diff"

        case .timelineStep(let step):
            return step.title
        }
    }
}

private enum TerminalOverlaySmokeApprovalChoice:
    Sendable,
    Hashable
{
    case approve
    case inspectDetails
    case showDiff
    case deny

    var title: String {
        switch self {
        case .approve:
            return "Approve"

        case .inspectDetails:
            return "Inspect details"

        case .showDiff:
            return "Show diff"

        case .deny:
            return "Deny"
        }
    }
}

private struct TerminalOverlaySmokeMessage:
    Sendable,
    Hashable
{
    var id: Int
    var role: String
    var body: String
    var contents: [TerminalOverlaySmokeContent]

    init(
        id: Int,
        role: String,
        body: String,
        contents: [TerminalOverlaySmokeContent] = []
    ) {
        self.id = id
        self.role = role
        self.body = body
        self.contents = contents
    }
}

private struct TerminalOverlaySmokeTranscriptLayout {
    var lines: [String]
    var messageRows: [Int: Range<Int>]
}

enum TerminalOverlaySmoke {
    static func run() throws {
        let stream = TerminalStream.standardError
        let session = try TerminalSession(
            options: TerminalSession.Options(
                useAlternateScreen: true,
                hideCursor: true,
                useRawMode: true,
                useBracketedPaste: true,
                keyboardProtocol: .kitty,
                controlSignalBehavior: .input,
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
        var keyMap = TerminalKeyMap<TerminalOverlaySmokeKeyAction>()
        keyMap.remap(
            .control("C"),
            to: .escape
        )
        keyMap.bindAction(
            TerminalKeyStroke(
                key: .enter,
                modifiers: .control
            ),
            to: .submit
        )
        var focus = TerminalFocusStack(
            TerminalOverlaySmokeFocus.base
        )
        var navigation = TerminalListControl(
            items: TerminalOverlaySmokeDestination.allCases,
            currentID: TerminalOverlaySmokeDestination.current,
            id: {
                $0
            }
        )
        var composer = TerminalTextSurface(
            editor: TerminalTextEditor(
                mode: .insert
            ),
            sizePolicy: TerminalTextSurfaceSizePolicy(
                minimumRows: 1,
                maximumRows: 6
            ),
            compactEditorPresentation: TerminalTextEditorPresentation(
                lineNumbers: .hybrid,
                indentationGuides: TerminalIndentationGuideOptions(
                    isEnabled: true,
                    width: 4,
                    glyph: "│"
                )
            ),
            expandedEditorPresentation: TerminalTextEditorPresentation(
                lineNumbers: .hybrid,
                indentationGuides: TerminalIndentationGuideOptions(
                    isEnabled: true,
                    width: 4,
                    glyph: "│"
                )
            ),
            placeholder: "type a message..."
        )
        var commandLine = TerminalCommandLine()
        let inputBufferStore = TerminalInputBufferStore()
        let inputBufferID = TerminalInputBufferID()
        var timeline = TerminalListControl(
            items: TerminalOverlaySmokeTimelineStep.allCases,
            currentID: TerminalOverlaySmokeTimelineStep.swiftBuild,
            id: {
                $0
            }
        )
        var timelineDocument = TerminalScrollableDocument(
            visibleRows: 0
        )
        var pendingContents: [TerminalOverlaySmokeContent] = []
        var editingPendingContentIndex: Int?
        var approval = TerminalListControl(
            items: approvalItems,
            currentID: TerminalOverlaySmokeApprovalChoice.approve,
            id: {
                $0.id
            }
        )
        var quitConfirmation = TerminalListControl(
            items: quitItems,
            currentID: TerminalOverlaySmokeQuitChoice.cancel,
            id: {
                $0.id
            }
        )
        var transcriptDocument = TerminalScrollableDocument(
            visibleRows: 0,
            followEnd: true
        )
        var inspectedMessageID: Int?
        var inspectedContentIndex = 0
        var messageDocument = TerminalScrollableDocument(
            visibleRows: 0
        )
        var inspector: TerminalOverlaySmokeInspector?
        var inspectorDocument = TerminalScrollableDocument(
            visibleRows: 0
        )
        var inspectorInteraction = Swim.ModalInteraction(
            mode: .normal
        )
        var messages = [
            TerminalOverlaySmokeMessage(
                id: 1,
                role: "you",
                body: "Keep the underlying shell alive while transient interfaces appear above it."
            ),
            TerminalOverlaySmokeMessage(
                id: 2,
                role: "assistant",
                body: "The frame can now prove modal focus capture without changing application semantics."
            ),
        ]
        var selectedMessageID = messages.last?.id
        var nextMessageID = 3
        var size = Terminal.size(
            for: stream
        )

        func renderCurrent() {
            renderer.render(
                frame(
                    size: size,
                    focus: focus,
                    navigation: navigation,
                    timeline: timeline,
                    timelineDocument: &timelineDocument,
                    composer: &composer,
                    commandLine: commandLine,
                    pendingContents: &pendingContents,
                    editingPendingContentIndex: editingPendingContentIndex,
                    selectedMessageID: selectedMessageID,
                    inspectedMessageID: inspectedMessageID,
                    inspectedContentIndex: inspectedContentIndex,
                    messageDocument: &messageDocument,
                    approval: approval,
                    quitConfirmation: quitConfirmation,
                    transcriptDocument: &transcriptDocument,
                    inspector: inspector,
                    inspectorDocument: &inspectorDocument,
                    messages: messages
                )
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

                if currentSize.rows != size.rows
                    || currentSize.columns != size.columns
                {
                    size = currentSize
                    renderCurrent()
                }

                continue
            }

            for event in events {
                if case .paste(let text) = event {
                    switch focus.current {
                    case .base:
                        let normalized = TerminalTextBuffer(
                            text: text
                        ).text

                        if normalized.isEmpty {
                            continue
                        }

                        if normalized.contains("\n") {
                            pendingContents.append(
                                .pastedText(
                                    TerminalOverlaySmokePaste(
                                        normalized
                                    )
                                )
                            )
                        } else {
                            _ = composer.handle(
                                event
                            )
                        }

                    case .composerSheet:
                        _ = composer.handle(
                            event
                        )

                    case .editor:
                        if let index = editingPendingContentIndex,
                           pendingContents.indices.contains(index),
                           case .pastedText(var paste) = pendingContents[index] {
                            _ = paste.buffer.editor.handle(
                                event
                            )
                            pendingContents[index] = .pastedText(
                                paste
                            )
                        }

                    case .transcript,
                         .navigation,
                         .timeline,
                         .messageInspector,
                         .approval,
                         .inspector,
                         .quitConfirmation:
                        break
                    }

                    continue
                }

            guard let keyStroke = event.keyStroke else {
                continue
            }

            let key: TerminalKey

            switch keyMap.resolveOrFallback(
                keyStroke
            ) {
            case .key(let resolvedKey):
                key = resolvedKey

            case .action(.submit):
                guard focus.current == .base
                    || focus.current == .composerSheet
                else {
                    continue
                }

                if let submittedMessageID = submit(
                    composer: &composer,
                    pendingContents: &pendingContents,
                    messages: &messages,
                    nextMessageID: &nextMessageID
                ) {
                    selectedMessageID = submittedMessageID
                    transcriptDocument.moveToEnd()
                }

                continue

            case .consumed:
                continue
            }

            if commandLine.isActive {
                switch commandLine.handle(
                    key
                ) {
                case .editing:
                    break

                case .cancelled:
                    break

                case .command(let command):
                    switch command {
                    case .write:
                        let text: String
                        let id: TerminalInputBufferID

                        if focus.current == .editor,
                           let index = editingPendingContentIndex,
                           pendingContents.indices.contains(index),
                           let paste = pendingContents[index].pastedTextValue {
                            text = paste.text
                            id = paste.id
                        } else {
                            text = composer.text
                            id = inputBufferID
                        }

                        do {
                            let destination = try inputBufferStore.write(
                                text,
                                id: id
                            )

                            commandLine.setStatus(
                                "\"\(destination.path)\" written"
                            )
                        } catch {
                            commandLine.setStatus(
                                "E212: Can't open file for writing: \(error)"
                            )
                        }

                    case .quit:
                        if focus.current == .editor {
                            editingPendingContentIndex = nil
                            _ = focus.pop()
                        } else if focus.current == .composerSheet {
                            composer.setPresentation(
                                .compact
                            )
                            _ = focus.pop()
                        } else {
                            _ = quitConfirmation.select(
                                id: .cancel
                            )

                            if focus.current != .quitConfirmation {
                                focus.push(
                                    .quitConfirmation
                                )
                            }
                        }
                    }

                case .invalid(let command):
                    commandLine.setStatus(
                        "E492: Not an editor command: \(command)"
                    )

                case .inactive:
                    break
                }

                continue
            }

            switch focus.current {
            case .base:
                switch key {
                case .control("C"),
                     .control("D"):
                    return

                case .control("F"):
                    composer.setPresentation(
                        .expanded
                    )
                    focus.push(
                        .composerSheet
                    )

                case .control("O"):
                    _ = approval.select(
                        id: .approve
                    )
                    focus.push(
                        .approval
                    )

                case .tab:
                    if composer.mode == .insert
                        || composer.mode == .replace
                    {
                        _ = composer.handle(
                            key
                        )
                    } else if navigation.currentID == .current {
                        if selectedMessageID == nil {
                            selectedMessageID = messages.last?.id
                        }

                        focus.replace(
                            .transcript
                        )
                    } else {
                        focus.replace(
                            .navigation
                        )
                    }

                case .control("E"):
                    if let index = pendingContents.indices.last(
                        where: {
                            pendingContents[$0].pastedTextValue != nil
                        }
                    ) {
                        editingPendingContentIndex = index
                        focus.push(
                            .editor
                        )
                    } else {
                        _ = composer.handle(
                            key
                        )
                    }

                case .control("X"):
                    if !pendingContents.isEmpty {
                        pendingContents.removeLast()
                    } else {
                        _ = composer.handle(
                            key
                        )
                    }

                case .pageUp,
                     .pageDown:
                    _ = composer.handle(
                        key
                    )

                case .control("U"):
                    _ = transcriptDocument.handle(
                        .motion(
                            .pageUp
                        )
                    )

                case .enter:
                    _ = composer.handle(
                        key
                    )

                default:
                    if case .commandLineRequested? = composer.handle(
                        key
                    ) {
                        commandLine.begin()
                    }
                }

            case .composerSheet:
                switch key {
                case .control("C"):
                    return

                case .control("F"):
                    composer.setPresentation(
                        .compact
                    )
                    _ = focus.pop()

                default:
                    if case .commandLineRequested? = composer.handle(
                        key
                    ) {
                        commandLine.begin()
                    }
                }

            case .transcript:
                switch key {
                case .control("C"):
                    return

                case .tab:
                    focus.replace(
                        .navigation
                    )

                case .escape:
                    focus.replace(
                        .base
                    )

                case .up,
                     .char("k"):
                    moveSelectedMessage(
                        by: -1,
                        messages: messages,
                        selectedMessageID: &selectedMessageID
                    )

                case .down,
                     .char("j"):
                    moveSelectedMessage(
                        by: 1,
                        messages: messages,
                        selectedMessageID: &selectedMessageID
                    )

                case .home:
                    selectedMessageID = messages.first?.id

                case .end:
                    selectedMessageID = messages.last?.id

                case .enter:
                    guard let selectedMessageID,
                          messages.contains(
                            where: {
                                $0.id == selectedMessageID
                            }
                          ) else {
                        continue
                    }

                    inspectedMessageID = selectedMessageID
                    inspectedContentIndex = 0
                    messageDocument = TerminalScrollableDocument(
                        visibleRows: 0
                    )
                    focus.push(
                        .messageInspector
                    )

                default:
                    continue
                }

            case .navigation:
                if key == .control("C") {
                    return
                }

                if key == .tab {
                    focus.replace(
                        .base
                    )
                } else {
                    guard let navigationEvent = navigation.handle(
                        key
                    ) else {
                        continue
                    }

                    switch navigationEvent {
                    case .currentChanged:
                        break

                    case .cancelRequested:
                        focus.replace(
                            .base
                        )

                    case .accepted(let destination):
                        if destination == .current {
                            if selectedMessageID == nil {
                                selectedMessageID = messages.last?.id
                            }

                            focus.replace(
                                .transcript
                            )
                        } else if destination == .runs {
                            focus.push(
                                .timeline
                            )
                        } else {
                            focus.replace(
                                .base
                            )
                        }
                    }
                }

            case .timeline:
                if key == .control("C") {
                    return
                }

                guard let timelineEvent = timeline.handle(
                    key
                ) else {
                    continue
                }

                switch timelineEvent {
                case .currentChanged:
                    break

                case .cancelRequested:
                    _ = focus.pop()

                case .accepted(let step):
                    inspector = .timelineStep(
                        step
                    )
                    inspectorDocument.moveToStart()
                    inspectorInteraction.setMode(
                        .normal
                    )
                    focus.push(
                        .inspector
                    )
                }

            case .messageInspector:
                guard let messageID = inspectedMessageID,
                      let message = messages.first(
                        where: {
                            $0.id == messageID
                        }
                      ) else {
                    inspectedMessageID = nil
                    inspectedContentIndex = 0
                    _ = focus.pop()
                    continue
                }

                switch key {
                case .control("C"):
                    return

                case .escape:
                    inspectedMessageID = nil
                    inspectedContentIndex = 0
                    _ = focus.pop()

                case .left,
                     .char("h"):
                    guard !message.contents.isEmpty,
                          inspectedContentIndex > 0 else {
                        continue
                    }

                    inspectedContentIndex -= 1
                    messageDocument.moveToStart()

                case .right,
                     .char("l"):
                    guard !message.contents.isEmpty,
                          inspectedContentIndex < message.contents.count - 1 else {
                        continue
                    }

                    inspectedContentIndex += 1
                    messageDocument.moveToStart()

                case .up,
                     .char("k"):
                    _ = messageDocument.handle(
                        .motion(
                            .up
                        )
                    )

                case .down,
                     .char("j"):
                    _ = messageDocument.handle(
                        .motion(
                            .down
                        )
                    )

                case .pageUp,
                     .control("U"):
                    _ = messageDocument.handle(
                        .motion(
                            .pageUp
                        )
                    )

                case .pageDown,
                     .control("D"):
                    _ = messageDocument.handle(
                        .motion(
                            .pageDown
                        )
                    )

                case .home:
                    messageDocument.moveToStart()

                case .end:
                    messageDocument.moveToEnd()

                default:
                    continue
                }

            case .approval:
                switch key {
                case .control("C"):
                    return

                case .escape:
                    _ = focus.pop()

                default:
                    guard case .accepted(let choice)? =
                        approval.handle(
                            key
                        ) else {
                        continue
                    }

                    switch choice {
                    case .approve:
                        messages.append(
                            TerminalOverlaySmokeMessage(
                                id: nextMessageID,
                                role: "system",
                                body: "Approval accepted. Underlying shell state remained intact."
                            )
                        )
                        nextMessageID += 1
                        selectedMessageID = messages.last?.id
                        transcriptDocument.moveToEnd()
                        _ = focus.pop()

                    case .deny:
                        messages.append(
                            TerminalOverlaySmokeMessage(
                                id: nextMessageID,
                                role: "system",
                                body: "Approval denied. Underlying shell state remained intact."
                            )
                        )
                        nextMessageID += 1
                        selectedMessageID = messages.last?.id
                        transcriptDocument.moveToEnd()
                        _ = focus.pop()

                    case .inspectDetails:
                        inspector = .details
                        inspectorDocument.moveToStart()
                        inspectorInteraction.setMode(
                            .normal
                        )
                        focus.push(
                            .inspector
                        )

                    case .showDiff:
                        inspector = .difference
                        inspectorDocument.moveToStart()
                        inspectorInteraction.setMode(
                            .normal
                        )
                        focus.push(
                            .inspector
                        )
                    }
                }

            case .inspector:
                if key == .control("C") {
                    return
                }

                switch inspectorInteraction.handle(
                    key.swimInput
                ) {
                case .consumed:
                    continue

                case .unhandled:
                    guard key == .escape else {
                        continue
                    }

                    inspector = nil
                    _ = focus.pop()

                case .action(let action):
                    if !inspectorDocument.handle(
                        action
                    ) {
                        inspectorInteraction.setMode(
                            .normal
                        )
                    }
                }

            case .editor:
                switch key {
                case .control("P"):
                    editingPendingContentIndex = movedPastedContentIndex(
                        from: editingPendingContentIndex,
                        by: -1,
                        in: pendingContents
                    )
                    continue

                case .control("N"):
                    editingPendingContentIndex = movedPastedContentIndex(
                        from: editingPendingContentIndex,
                        by: 1,
                        in: pendingContents
                    )
                    continue

                default:
                    break
                }

                guard let index = editingPendingContentIndex,
                      pendingContents.indices.contains(index),
                      case .pastedText(var paste) = pendingContents[index] else {
                    editingPendingContentIndex = nil
                    _ = focus.pop()
                    continue
                }

                let editorEvent = paste.buffer.editor.handle(
                    key
                )
                pendingContents[index] = .pastedText(
                    paste
                )

                switch editorEvent {
                case .commandLineRequested?:
                    commandLine.begin()

                case .cancelRequested?:
                    if paste.text.isEmpty {
                        pendingContents.remove(
                            at: index
                        )
                    }

                    editingPendingContentIndex = nil
                    _ = focus.pop()

                default:
                    break
                }

            case .quitConfirmation:
                switch key {
                case .escape:
                    _ = focus.pop()

                default:
                    guard case .accepted(let choice)? =
                        quitConfirmation.handle(
                            key
                        ) else {
                        continue
                    }

                    switch choice {
                    case .cancel:
                        _ = focus.pop()

                    case .quit:
                        return
                    }
                }
            }
            }

            size = Terminal.size(
                for: stream
            )
            renderCurrent()
        }
    }

    private struct ApprovalItem:
        Sendable
    {
        var id: TerminalOverlaySmokeApprovalChoice
        var title: String
    }

    private struct QuitItem:
        Sendable
    {
        var id: TerminalOverlaySmokeQuitChoice
        var title: String
    }

    private static let quitItems = [
        QuitItem(
            id: .cancel,
            title: TerminalOverlaySmokeQuitChoice.cancel.title
        ),
        QuitItem(
            id: .quit,
            title: TerminalOverlaySmokeQuitChoice.quit.title
        ),
    ]

    private static let approvalItems = [
        ApprovalItem(
            id: .approve,
            title: TerminalOverlaySmokeApprovalChoice.approve.title
        ),
        ApprovalItem(
            id: .inspectDetails,
            title: TerminalOverlaySmokeApprovalChoice.inspectDetails.title
        ),
        ApprovalItem(
            id: .showDiff,
            title: TerminalOverlaySmokeApprovalChoice.showDiff.title
        ),
        ApprovalItem(
            id: .deny,
            title: TerminalOverlaySmokeApprovalChoice.deny.title
        ),
    ]

    private static func submit(
        composer: inout TerminalTextSurface,
        pendingContents: inout [TerminalOverlaySmokeContent],
        messages: inout [TerminalOverlaySmokeMessage],
        nextMessageID: inout Int
    ) -> Int? {
        let inlineText = composer.text
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !inlineText.isEmpty
            || !pendingContents.isEmpty else {
            return nil
        }

        let submittedMessageID = nextMessageID

        messages.append(
            TerminalOverlaySmokeMessage(
                id: nextMessageID,
                role: "you",
                body: inlineText,
                contents: pendingContents
            )
        )
        nextMessageID += 1

        messages.append(
            TerminalOverlaySmokeMessage(
                id: nextMessageID,
                role: "assistant",
                body: "Composer state and retained message content remain owned by the base shell."
            )
        )
        nextMessageID += 1

        composer.clear()
        composer.setMode(
            .insert
        )
        pendingContents.removeAll(
            keepingCapacity: true
        )

        return submittedMessageID
    }

    private static func frame(
        size: TerminalSize,
        focus: TerminalFocusStack<TerminalOverlaySmokeFocus>,
        navigation: TerminalListControl<
            TerminalOverlaySmokeDestination,
            TerminalOverlaySmokeDestination
        >,
        timeline: TerminalListControl<
            TerminalOverlaySmokeTimelineStep,
            TerminalOverlaySmokeTimelineStep
        >,
        timelineDocument: inout TerminalScrollableDocument,
        composer: inout TerminalTextSurface,
        commandLine: TerminalCommandLine,
        pendingContents: inout [TerminalOverlaySmokeContent],
        editingPendingContentIndex: Int?,
        selectedMessageID: Int?,
        inspectedMessageID: Int?,
        inspectedContentIndex: Int,
        messageDocument: inout TerminalScrollableDocument,
        approval: TerminalListControl<
            ApprovalItem,
            TerminalOverlaySmokeApprovalChoice
        >,
        quitConfirmation: TerminalListControl<
            QuitItem,
            TerminalOverlaySmokeQuitChoice
        >,
        transcriptDocument: inout TerminalScrollableDocument,
        inspector: TerminalOverlaySmokeInspector?,
        inspectorDocument: inout TerminalScrollableDocument,
        messages: [TerminalOverlaySmokeMessage]
    ) -> TerminalFrame {
        var frame = baseFrame(
            size: size,
            navigation: navigation,
            timeline: timeline,
            timelineDocument: &timelineDocument,
            composer: &composer,
            commandLine: commandLine,
            composerFocused:
                focus.current == .base,
            transcriptFocused:
                focus.current == .transcript
                    || focus.current == .messageInspector,
            navigationFocused:
                focus.current == .navigation,
            timelineFocused:
                focus.current == .timeline,
            pendingContents: pendingContents,
            selectedMessageID: selectedMessageID,
            transcriptDocument: &transcriptDocument,
            messages: messages
        )
        let root = TerminalRegion(
            rows: size.rows,
            columns: size.columns
        )

        switch focus.current {
        case .base,
             .transcript,
             .navigation,
             .timeline:
            break

        case .composerSheet:
            renderComposerSheet(
                into: &frame,
                in: root,
                composer: &composer,
                commandLine: commandLine
            )

        case .messageInspector:
            if let inspectedMessageID,
               let message = messages.first(
                where: {
                    $0.id == inspectedMessageID
                }
               ) {
                renderMessageInspector(
                    message,
                    contentIndex: inspectedContentIndex,
                    into: &frame,
                    in: root,
                    document: &messageDocument
                )
            }

        case .approval:
            renderApproval(
                into: &frame,
                in: root,
                approval: approval
            )

        case .inspector:
            if let inspector {
                renderInspector(
                    inspector,
                    into: &frame,
                    in: root,
                    document: &inspectorDocument
                )
            }

        case .editor:
            if let index = editingPendingContentIndex,
               pendingContents.indices.contains(index),
               case .pastedText(var paste) = pendingContents[index] {
                renderEditor(
                    into: &frame,
                    in: root,
                    editor: &paste.buffer.editor,
                    bufferIndex: index + 1,
                    bufferCount: pendingContents.count,
                    commandLine: commandLine
                )
                pendingContents[index] = .pastedText(
                    paste
                )
            }

        case .quitConfirmation:
            renderQuitConfirmation(
                into: &frame,
                in: root,
                confirmation: quitConfirmation
            )
        }

        return frame
    }

    private static func baseFrame(
        size: TerminalSize,
        navigation: TerminalListControl<
            TerminalOverlaySmokeDestination,
            TerminalOverlaySmokeDestination
        >,
        timeline: TerminalListControl<
            TerminalOverlaySmokeTimelineStep,
            TerminalOverlaySmokeTimelineStep
        >,
        timelineDocument: inout TerminalScrollableDocument,
        composer: inout TerminalTextSurface,
        commandLine: TerminalCommandLine,
        composerFocused: Bool,
        transcriptFocused: Bool,
        navigationFocused: Bool,
        timelineFocused: Bool,
        pendingContents: [TerminalOverlaySmokeContent],
        selectedMessageID: Int?,
        transcriptDocument: inout TerminalScrollableDocument,
        messages: [TerminalOverlaySmokeMessage]
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
        let composerColumns = max(
            1,
            root.columns - 2
        )
        let composerRows = composer.compactRows(
            columns: composerColumns
        )
        let footerRows = min(
            root.rows,
            composerRows + 3
        )
        let vertical = TerminalLayout.vertical(
            in: root,
            [
                .fixed(2),
                .flex(1),
                .fixed(footerRows),
            ],
            spacing: 1
        )
        let header = vertical[0]
        let body = vertical[1]
        let footer = vertical[2]
        let destination = navigation.currentID
            ?? TerminalOverlaySmokeDestination.current

        frame.write(
            [
                TerminalStyle.bold.apply(
                    "terminal shell"
                ),
                TerminalStyle.dim.apply(
                    "overlay composition laboratory"
                ),
            ],
            in: header
        )

        let railColumns = min(
            18,
            max(
                8,
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

        renderNavigationRail(
            navigation: navigation,
            focused: navigationFocused,
            into: &frame,
            in: horizontal[0]
        )

        switch destination {
        case .current:
            let transcriptLayout = transcriptLayout(
                messages,
                width: horizontal[1].columns,
                selectedMessageID: transcriptFocused
                    ? selectedMessageID
                    : nil
            )

            transcriptDocument.update(
                lines: transcriptLayout.lines,
                visibleRows: horizontal[1].rows
            )

            if transcriptFocused,
               let selectedMessageID,
               let selectedRows = transcriptLayout.messageRows[selectedMessageID] {
                transcriptDocument.reveal(
                    row: selectedRows.lowerBound,
                    margin: 1
                )
            }

            transcriptDocument.render(
                into: &frame,
                in: horizontal[1]
            )

        case .runs:
            renderTimeline(
                timeline: timeline,
                into: &frame,
                in: horizontal[1],
                document: &timelineDocument
            )

        case .previous,
             .tools,
             .tasks:
            renderDestination(
                destination,
                into: &frame,
                in: horizontal[1]
            )
        }

        if footer.rows > 0 {
            frame.write(
                TerminalStyle.dim.apply(
                    String(
                        repeating: "─",
                        count: footer.columns
                    )
                ),
                in: TerminalRegion(
                    top: footer.top,
                    leading: footer.leading,
                    rows: 1,
                    columns: footer.columns
                )
            )
        }

        if footer.rows > 1,
           composerRows > 0
        {
            frame.write(
                "> ",
                in: TerminalRegion(
                    top: footer.top + 1,
                    leading: footer.leading,
                    rows: 1,
                    columns: min(
                        2,
                        footer.columns
                    )
                )
            )

            composer.render(
                into: &frame,
                in: TerminalRegion(
                    top: footer.top + 1,
                    leading: footer.leading + min(
                        2,
                        footer.columns
                    ),
                    rows: min(
                        composerRows,
                        max(
                            0,
                            footer.rows - 3
                        )
                    ),
                    columns: composerColumns
                ),
                isFocused: composerFocused
            )
        }

        if footer.rows > composerRows + 1,
           let latestContent = pendingContents.last {
            let label = pendingContents.count == 1
                ? latestContent.summary
                : "\(pendingContents.count) contents · latest \(latestContent.summary)"
            let summary = TerminalDisplay.fitted(
                "\(label)  ctrl-e edit latest  ctrl-x remove latest",
                columns: footer.columns
            )

            frame.write(
                TerminalStyle(
                    .inverse
                ).apply(
                    summary
                ),
                in: TerminalRegion(
                    top: footer.top + 1 + composerRows,
                    leading: footer.leading,
                    rows: 1,
                    columns: footer.columns
                )
            )
        }

        if footer.rows > 0 {
            let commandRegion = TerminalRegion(
                top: footer.bottom - 1,
                leading: footer.leading,
                rows: 1,
                columns: footer.columns
            )

            if commandLine.hasPresentation {
                commandLine.render(
                    into: &frame,
                    in: commandRegion,
                    isFocused: composerFocused
                )
            } else {
                let hint: String

                if navigationFocused {
                    hint = "j/k navigate  enter open  tab composer  esc back"
                } else if timelineFocused {
                    hint = "j/k select step  enter inspect  esc back"
                } else if transcriptFocused {
                    hint = "j/k select message  enter inspect  tab navigation  esc back"
                } else if destination == .current {
                    hint = "enter edit · ctrl-enter submit · ctrl-c normal · :w save · :q quit · ctrl-f expand"
                } else {
                    hint = "tab navigation  composer retained  ctrl-o approval  esc back"
                }

                frame.write(
                    TerminalStyle.dim.apply(
                        hint
                    ),
                    in: commandRegion
                )
            }
        }

        return frame
    }

    private static func renderNavigationRail(
        navigation: TerminalListControl<
            TerminalOverlaySmokeDestination,
            TerminalOverlaySmokeDestination
        >,
        focused: Bool,
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        let rows = navigation.rows()

        frame.write(
            [
                TerminalStyle.dim.apply(
                    "sessions"
                ),
                navigationLine(
                    .current,
                    rows: rows,
                    focused: focused
                ),
                navigationLine(
                    .previous,
                    rows: rows,
                    focused: focused
                ),
                "",
                TerminalStyle.dim.apply(
                    "views"
                ),
                navigationLine(
                    .runs,
                    rows: rows,
                    focused: focused
                ),
                navigationLine(
                    .tools,
                    rows: rows,
                    focused: focused
                ),
                navigationLine(
                    .tasks,
                    rows: rows,
                    focused: focused
                ),
            ],
            in: region
        )
    }

    private static func navigationLine(
        _ destination: TerminalOverlaySmokeDestination,
        rows: [
            TerminalListControlRow<
                TerminalOverlaySmokeDestination,
                TerminalOverlaySmokeDestination
            >
        ],
        focused: Bool
    ) -> String {
        let line = "  \(destination.title)"

        guard let row = rows.first(
            where: {
                $0.id == destination
            }
        ),
              row.isCurrent else {
            return line
        }

        if focused {
            return TerminalStyle(
                .inverse
            ).apply(
                line
            )
        }

        return TerminalStyle.bold.apply(
            line
        )
    }

    private static func renderTimeline(
        timeline: TerminalListControl<
            TerminalOverlaySmokeTimelineStep,
            TerminalOverlaySmokeTimelineStep
        >,
        into frame: inout TerminalFrame,
        in region: TerminalRegion,
        document: inout TerminalScrollableDocument
    ) {
        let timelineLayout = TerminalTimeline(
            items: timeline.items.map(\.timelineItem)
        ).layout(
            width: region.columns,
            selectedID: timeline.currentID
        )
        let header = [
            TerminalStyle.bold.apply(
                "run detail"
            ),
            TerminalStyle.dim.apply(
                "ToolPlan · suspended at artest"
            ),
            "",
        ]
        let lines = header + timelineLayout.lines

        document.update(
            lines: lines,
            visibleRows: region.rows
        )

        if let selectedID = timeline.currentID,
           let selectedRows = timelineLayout.itemRows[selectedID] {
            document.reveal(
                row: header.count + selectedRows.lowerBound,
                margin: 1
            )
        }

        document.render(
            into: &frame,
            in: region
        )
    }

    private static func renderDestination(
        _ destination: TerminalOverlaySmokeDestination,
        into frame: inout TerminalFrame,
        in region: TerminalRegion
    ) {
        let lines: [String]

        switch destination {
        case .current:
            return

        case .previous:
            lines = [
                TerminalStyle.bold.apply(
                    "previous sessions"
                ),
                "",
                "  terminal composition",
                "  renderer investigation",
                "  input foundation",
                "",
                TerminalStyle.dim.apply(
                    "Mock destination; shell and composer state remain mounted."
                ),
            ]

        case .runs:
            return

        case .tools:
            lines = [
                TerminalStyle.bold.apply(
                    "tools"
                ),
                "",
                "  search",
                "  inspect",
                "  mutate",
                "  build",
                "",
                TerminalStyle.dim.apply(
                    "Terminal supplies presentation mechanics, not tool semantics."
                ),
            ]

        case .tasks:
            lines = [
                TerminalStyle.bold.apply(
                    "tasks"
                ),
                "",
                "  finish shell composition",
                "  connect interface semantics",
                "  connect runtime state",
                "",
                TerminalStyle.dim.apply(
                    "This remains a presentation laboratory."
                ),
            ]
        }

        frame.write(
            lines,
            in: region
        )
    }

    private static func transcriptLayout(
        _ messages: [TerminalOverlaySmokeMessage],
        width: Int,
        selectedMessageID: Int?
    ) -> TerminalOverlaySmokeTranscriptLayout {
        let width = max(
            1,
            width
        )
        var lines: [String] = []
        var messageRows: [Int: Range<Int>] = [:]

        for message in messages {
            let start = lines.count
            let isSelected = message.id == selectedMessageID

            if isSelected {
                lines.append(
                    TerminalStyle(
                        .inverse
                    ).apply(
                        TerminalDisplay.fitted(
                            message.role,
                            columns: width
                        )
                    )
                )
            } else {
                lines.append(
                    TerminalStyle.bold.apply(
                        message.role
                    )
                )
            }

            if !message.body.isEmpty {
                for bodyLine in TerminalTextWrap.lines(
                    message.body,
                    width: width
                ) {
                    if isSelected {
                        lines.append(
                            TerminalStyle(
                                .inverse
                            ).apply(
                                TerminalDisplay.fitted(
                                    bodyLine,
                                    columns: width
                                )
                            )
                        )
                    } else {
                        lines.append(
                            bodyLine
                        )
                    }
                }
            }

            for content in message.contents {
                let summary = "  [\(content.summary)]"

                if isSelected {
                    lines.append(
                        TerminalStyle(
                            .inverse
                        ).apply(
                            TerminalDisplay.fitted(
                                summary,
                                columns: width
                            )
                        )
                    )
                } else {
                    lines.append(
                        TerminalStyle.dim.apply(
                            summary
                        )
                    )
                }
            }

            messageRows[message.id] = start..<lines.count
            lines.append("")
        }

        lines.append(
            TerminalStyle.dim.apply(
                "activity"
            )
        )
        lines.append(
            "base frame remains mounted beneath transient surfaces"
        )

        return TerminalOverlaySmokeTranscriptLayout(
            lines: lines,
            messageRows: messageRows
        )
    }

    private static func moveSelectedMessage(
        by offset: Int,
        messages: [TerminalOverlaySmokeMessage],
        selectedMessageID: inout Int?
    ) {
        guard !messages.isEmpty else {
            selectedMessageID = nil
            return
        }

        let currentIndex = selectedMessageID
            .flatMap {
                selectedMessageID in

                messages.firstIndex {
                    $0.id == selectedMessageID
                }
            }
            ?? messages.count - 1
        let nextIndex = min(
            messages.count - 1,
            max(
                0,
                currentIndex + offset
            )
        )

        selectedMessageID = messages[nextIndex].id
    }

    private static func renderQuitConfirmation(
        into frame: inout TerminalFrame,
        in root: TerminalRegion,
        confirmation: TerminalListControl<
            QuitItem,
            TerminalOverlaySmokeQuitChoice
        >
    ) {
        let overlay = TerminalOverlay(
            placement: .centered(
                columns: 44,
                rows: 9
            ),
            outerInsets: TerminalInsets(
                vertical: 1,
                horizontal: 2
            )
        )
        let content = overlay.render(
            into: &frame,
            in: root,
            title: "quit terminal shell?"
        )

        guard !content.isEmpty else {
            return
        }

        var lines = [
            TerminalStyle.bold.apply(
                "Quit the current terminal session?"
            ),
            TerminalStyle.dim.apply(
                "The current composer state will be discarded."
            ),
            "",
        ]

        for row in confirmation.rows() {
            if row.isCurrent {
                lines.append(
                    TerminalStyle(
                        .inverse
                    ).apply(
                        TerminalDisplay.fitted(
                            "> " + row.item.title,
                            columns: content.columns
                        )
                    )
                )
            } else {
                lines.append(
                    "  " + row.item.title
                )
            }
        }

        lines.append("")
        lines.append(
            TerminalStyle.dim.apply(
                "↑/↓ choose  enter confirm  esc/ctrl-c cancel"
            )
        )

        frame.write(
            lines,
            in: content
        )
    }

    private static func renderApproval(
        into frame: inout TerminalFrame,
        in root: TerminalRegion,
        approval: TerminalListControl<
            ApprovalItem,
            TerminalOverlaySmokeApprovalChoice
        >
    ) {
        let overlay = TerminalOverlay(
            placement: .centered(
                columns: 56,
                rows: 15
            ),
            outerInsets: TerminalInsets(
                vertical: 1,
                horizontal: 2
            )
        )
        let content = overlay.render(
            into: &frame,
            in: root,
            title: "tool approval requested"
        )

        guard !content.isEmpty else {
            return
        }

        var lines = [
            TerminalStyle.bold.apply(
                "mutate_files"
            ),
            "3 file mutations",
            TerminalStyle.dim.apply(
                "risk  medium"
            ),
            "",
        ]

        for row in approval.rows() {
            let line = "  " + row.item.title

            if row.isCurrent {
                lines.append(
                    TerminalStyle(
                        .inverse
                    ).apply(
                        TerminalDisplay.fitted(
                            "> " + row.item.title,
                            columns: content.columns
                        )
                    )
                )
            } else {
                lines.append(
                    line
                )
            }
        }

        lines.append("")
        lines.append(
            TerminalStyle.dim.apply(
                "↑/↓ choose  enter open  esc dismiss"
            )
        )

        frame.write(
            lines,
            in: content
        )
    }

    private static func renderMessageInspector(
        _ message: TerminalOverlaySmokeMessage,
        contentIndex: Int,
        into frame: inout TerminalFrame,
        in root: TerminalRegion,
        document: inout TerminalScrollableDocument
    ) {
        let contentCount = message.contents.count
        let resolvedContentIndex = contentCount == 0
            ? 0
            : min(
                contentCount - 1,
                max(
                    0,
                    contentIndex
                )
            )
        let currentContent = contentCount == 0
            ? nil
            : message.contents[resolvedContentIndex]
        let title: String

        if contentCount > 0 {
            title = "message \(message.id) · \(message.role) · content \(resolvedContentIndex + 1)/\(contentCount)"
        } else {
            title = "message \(message.id) · \(message.role)"
        }

        let overlay = TerminalOverlay(
            placement: .centered(
                columns: 86,
                rows: 28
            ),
            outerInsets: TerminalInsets(
                vertical: 1,
                horizontal: 2
            )
        )
        let content = overlay.render(
            into: &frame,
            in: root,
            title: title
        )

        guard !content.isEmpty else {
            return
        }

        var lines: [String] = []

        if !message.body.isEmpty {
            lines.append(
                TerminalStyle.bold.apply(
                    "message"
                )
            )
            lines.append(
                contentsOf: TerminalTextWrap.lines(
                    message.body,
                    width: max(
                        1,
                        content.columns
                    )
                )
            )

            if currentContent != nil {
                lines.append("")
            }
        }

        if let currentContent {
            lines.append(
                TerminalStyle.bold.apply(
                    "content"
                )
            )
            lines.append(
                contentsOf: currentContent.renderedLines(
                    width: content.columns
                )
            )
        }

        if lines.isEmpty {
            lines.append("")
        }

        let documentRows = max(
            0,
            content.rows - 2
        )
        let documentRegion = TerminalRegion(
            top: content.top,
            leading: content.leading,
            rows: documentRows,
            columns: content.columns
        )

        document.update(
            lines: lines,
            visibleRows: documentRows
        )
        document.render(
            into: &frame,
            in: documentRegion
        )

        if content.rows > 1 {
            let status: String

            if let currentContent {
                status = currentContent.summary
                    + " · "
                    + "\(resolvedContentIndex + 1)/\(contentCount)"
            } else {
                status = "message body"
            }

            frame.write(
                TerminalStyle.dim.apply(
                    status
                ),
                in: TerminalRegion(
                    top: content.bottom - 2,
                    leading: content.leading,
                    rows: 1,
                    columns: content.columns
                )
            )
        }

        if content.rows > 0 {
            let instructions: String

            if contentCount > 1 {
                instructions = "h/l content  j/k scroll  pgup/pgdn page  home/end ends  esc back"
            } else {
                instructions = "j/k scroll  pgup/pgdn page  home/end ends  esc back"
            }

            frame.write(
                TerminalStyle.dim.apply(
                    instructions
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

    private static func renderComposerSheet(
        into frame: inout TerminalFrame,
        in root: TerminalRegion,
        composer: inout TerminalTextSurface,
        commandLine: TerminalCommandLine
    ) {
        let overlay = TerminalOverlay(
            placement: .centered(
                columns: max(
                    0,
                    root.columns - 4
                ),
                rows: max(
                    0,
                    root.rows - 2
                )
            ),
            outerInsets: .zero,
            contentInsets: TerminalInsets(
                vertical: 0,
                horizontal: 1
            )
        )
        let content = overlay.render(
            into: &frame,
            in: root,
            title: "message editor"
        )

        guard !content.isEmpty else {
            return
        }

        let editorRows = max(
            0,
            content.rows - 1
        )

        if editorRows > 0 {
            composer.render(
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
            let commandRegion = TerminalRegion(
                top: content.bottom - 1,
                leading: content.leading,
                rows: 1,
                columns: content.columns
            )

            if commandLine.hasPresentation {
                commandLine.render(
                    into: &frame,
                    in: commandRegion,
                    isFocused: true
                )
            } else {
                frame.write(
                    TerminalStyle.dim.apply(
                        "mode \(composer.mode) · ctrl-enter submit · ctrl-c normal · :w save · :q compact · ctrl-f compact"
                    ),
                    in: commandRegion
                )
            }
        }
    }

    private static func movedPastedContentIndex(
        from current: Int?,
        by offset: Int,
        in contents: [TerminalOverlaySmokeContent]
    ) -> Int? {
        let indices = contents.indices.filter {
            contents[$0].pastedTextValue != nil
        }

        guard !indices.isEmpty else {
            return nil
        }

        let currentPosition = current.flatMap {
            indices.firstIndex(
                of: $0
            )
        } ?? 0
        let nextPosition = (
            currentPosition
                + offset
                + indices.count
        ) % indices.count

        return indices[nextPosition]
    }

    private static func renderEditor(
        into frame: inout TerminalFrame,
        in root: TerminalRegion,
        editor: inout TerminalTextEditor,
        bufferIndex: Int,
        bufferCount: Int,
        commandLine: TerminalCommandLine
    ) {
        let overlay = TerminalOverlay(
            placement: .centered(
                columns: 78,
                rows: 24
            ),
            outerInsets: TerminalInsets(
                vertical: 1,
                horizontal: 2
            )
        )
        let content = overlay.render(
            into: &frame,
            in: root,
            title: "pasted text · \(bufferIndex)/\(bufferCount)"
        )

        guard !content.isEmpty else {
            return
        }

        let editorRows = max(
            0,
            content.rows - 1
        )

        if editorRows > 0 {
            editor.render(
                into: &frame,
                in: TerminalRegion(
                    top: content.top,
                    leading: content.leading,
                    rows: editorRows,
                    columns: content.columns
                ),
                isFocused: true,
                presentation: TerminalTextEditorPresentation(
                    lineNumbers: .hybrid,
                    indentationGuides: TerminalIndentationGuideOptions(
                        isEnabled: true,
                        width: 4,
                        glyph: "│"
                    )
                )
            )
        }

        if content.rows > 0 {
            let commandRegion = TerminalRegion(
                top: content.bottom - 1,
                leading: content.leading,
                rows: 1,
                columns: content.columns
            )

            if commandLine.hasPresentation {
                commandLine.render(
                    into: &frame,
                    in: commandRegion,
                    isFocused: true
                )
            } else {
                frame.write(
                    TerminalStyle.dim.apply(
                        "mode \(editor.mode) · u undo · ctrl-r redo · ctrl-p/n buffers · :w save · :q close · h/j/k/l move"
                    ),
                    in: commandRegion
                )
            }
        }
    }

    private static func renderInspector(
        _ inspector: TerminalOverlaySmokeInspector,
        into frame: inout TerminalFrame,
        in root: TerminalRegion,
        document: inout TerminalScrollableDocument
    ) {
        let overlay = TerminalOverlay(
            placement: .trailing(
                columns: 60
            ),
            outerInsets: TerminalInsets(
                vertical: 1,
                horizontal: 1
            )
        )
        let content = overlay.render(
            into: &frame,
            in: root,
            title: inspector.title
        )

        guard !content.isEmpty else {
            return
        }

        let lines = inspectorLines(
            inspector,
            width: content.columns
        )
        let visibleRows = max(
            0,
            content.rows - 2
        )
        let documentRegion = TerminalRegion(
            top: content.top,
            leading: content.leading,
            rows: visibleRows,
            columns: content.columns
        )

        document.update(
            lines: lines,
            visibleRows: visibleRows
        )
        document.render(
            into: &frame,
            in: documentRegion
        )

        if content.rows > 0 {
            frame.write(
                TerminalStyle.dim.apply(
                    "NORMAL  j/k scroll  gg/G ends  pgup/pgdn page  esc back"
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

    private static func inspectorLines(
        _ inspector: TerminalOverlaySmokeInspector,
        width: Int
    ) -> [String] {
        switch inspector {
        case .details:
            return detailsInspectorLines(
                width: width
            )

        case .difference:
            return differenceInspectorLines

        case .timelineStep(let step):
            return timelineStepInspectorLines(
                step,
                width: width
            )
        }
    }

    private static func timelineStepInspectorLines(
        _ step: TerminalOverlaySmokeTimelineStep,
        width: Int
    ) -> [String] {
        let block = TerminalBlock(
            title: "step",
            fields: [
                TerminalField(
                    "tool",
                    step.title
                ),
                TerminalField(
                    "state",
                    step.stateLabel
                ),
                TerminalField(
                    "target",
                    step.detail ?? "none"
                ),
            ],
            body: "Selection and execution state remain independent; this detail surface is the existing generic inspector overlay.",
            layout: TerminalBlockLayout(
                fieldIndent: 0,
                labelWidth: .minimum(6),
                labelValueSpacing: 3,
                blankLinesAfter: 0
            )
        )

        return block.render(
            width: width
        )
        .split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        .map(String.init)
    }

    private static func detailsInspectorLines(
        width: Int
    ) -> [String] {
        let layout = TerminalBlockLayout(
            fieldIndent: 0,
            labelWidth: .minimum(7),
            labelValueSpacing: 3,
            blankLinesAfter: 0
        )
        let blocks = [
            TerminalBlock(
                title: "preflight",
                fields: [
                    TerminalField(
                        "tool",
                        "mutate_files"
                    ),
                    TerminalField(
                        "risk",
                        "medium"
                    ),
                    TerminalField(
                        "targets",
                        "3 files"
                    ),
                ],
                layout: layout
            ),
            TerminalBlock(
                title: "intent",
                body: "Add reusable terminal overlay composition and nested focus restoration.",
                layout: layout
            ),
            TerminalBlock(
                title: "targets",
                body: [
                    "Terminal/Sources/Terminal/terminal-overlay.swift",
                    "Terminal/Sources/Terminal/terminal-focus-stack.swift",
                    "Terminal/Sources/TerminalTestFlows/terminal-overlay-smoke.swift",
                ].joined(
                    separator: "\n"
                ),
                layout: layout
            ),
        ]
        var lines = blocks.flatMap {
            block in

            block.render(
                width: width
            )
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .map(String.init)
        }

        lines.append(
            contentsOf: TerminalTextWrap.lines(
                "This content is deliberately longer than the smallest sheet so viewport behavior can be inspected.",
                width: width
            ).map(
                TerminalStyle.dim.apply
            )
        )

        return lines
    }

    private static let differenceInspectorLines: [String] = {
        let oldLines = (1...96).map {
            index in

            "let overlayRow\(index) = \"base-\(index)\""
        }
        var newLines = oldLines

        for index in stride(
            from: 4,
            through: 92,
            by: 8
        ) {
            newLines[index - 1] =
                "let overlayRow\(index) = \"composed-\(index)\""
        }

        newLines.insert(
            "let overlayStack = \"approval > diff inspector\"",
            at: 18
        )
        newLines.remove(
            at: 73
        )

        let difference = TextDiffer.diff(
            old: oldLines.joined(
                separator: "\n"
            ),
            new: newLines.joined(
                separator: "\n"
            ),
            oldName: "a/terminal-overlay-smoke.swift",
            newName: "b/terminal-overlay-smoke.swift"
        )

        return TerminalDifferenceRenderer.render(
            difference,
            options: .init(
                base: .init(
                    showEndOfFile: true
                )
            )
        )
        .split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        .map(String.init)
    }()
}
