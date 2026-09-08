public struct TerminalTextBufferSession:
    Sendable,
    Hashable
{
    public let id: TerminalInputBufferID
    public var editor: TerminalTextEditor

    public init(
        id: TerminalInputBufferID = TerminalInputBufferID(),
        text: String = ""
    ) {
        self.id = id
        self.editor = TerminalTextEditor(
            text: text
        )
    }

    public var text: String {
        editor.buffer.text
    }
}
