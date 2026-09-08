public enum TerminalLineNumberMode:
    Sendable,
    Hashable
{
    case hidden
    case absolute
    case relative
    case hybrid
}

public struct TerminalIndentationGuideOptions:
    Sendable,
    Hashable
{
    public var isEnabled: Bool
    public var width: Int
    public var glyph: String
    public var style: TerminalStyle

    public init(
        isEnabled: Bool = false,
        width: Int = 4,
        glyph: String = "│",
        style: TerminalStyle = .dim
    ) {
        self.isEnabled = isEnabled
        self.width = max(
            1,
            width
        )
        self.glyph = glyph.isEmpty
            ? "│"
            : glyph
        self.style = style
    }
}

public struct TerminalTextEditorPresentation:
    Sendable,
    Hashable
{
    public var lineNumbers: TerminalLineNumberMode
    public var lineNumberStyle: TerminalStyle
    public var currentLineNumberStyle: TerminalStyle
    public var selectionStyle: TerminalStyle
    public var indentationGuides: TerminalIndentationGuideOptions

    public init(
        lineNumbers: TerminalLineNumberMode = .hidden,
        lineNumberStyle: TerminalStyle = .dim,
        currentLineNumberStyle: TerminalStyle = .bold,
        selectionStyle: TerminalStyle = TerminalStyle(
            foreground: .rgb(
                red: 208,
                green: 208,
                blue: 208
            ),
            background: .rgb(
                red: 58,
                green: 61,
                blue: 67
            )
        ),
        indentationGuides: TerminalIndentationGuideOptions = .init()
    ) {
        self.lineNumbers = lineNumbers
        self.lineNumberStyle = lineNumberStyle
        self.currentLineNumberStyle = currentLineNumberStyle
        self.selectionStyle = selectionStyle
        self.indentationGuides = indentationGuides
    }

    public static let plain = TerminalTextEditorPresentation()

    public func gutterColumns(
        lineCount: Int,
        availableColumns: Int
    ) -> Int {
        guard lineNumbers != .hidden else {
            return 0
        }

        let desired = 7

        return min(
            desired,
            max(
                0,
                availableColumns - 1
            )
        )
    }

    func lineNumberText(
        sourceLineNumber: Int,
        currentLineNumber: Int,
        isSourceLineStart: Bool,
        gutterColumns: Int
    ) -> String {
        guard gutterColumns > 0 else {
            return ""
        }

        guard isSourceLineStart else {
            return String(
                repeating: " ",
                count: gutterColumns
            )
        }

        let value: Int

        switch lineNumbers {
        case .hidden:
            return String(
                repeating: " ",
                count: gutterColumns
            )

        case .absolute:
            value = sourceLineNumber

        case .relative:
            value = sourceLineNumber == currentLineNumber
                ? 0
                : abs(
                    sourceLineNumber - currentLineNumber
                )

        case .hybrid:
            value = sourceLineNumber == currentLineNumber
                ? sourceLineNumber
                : abs(
                    sourceLineNumber - currentLineNumber
                )
        }

        let number = String(
            value
        )
        let numberColumns = max(
            0,
            gutterColumns - 1
        )
        let padding = max(
            0,
            numberColumns - number.count
        )

        return String(
            repeating: " ",
            count: padding
        )
            + number
            + " "
    }
}
