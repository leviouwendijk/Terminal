public enum TerminalLineNumberMode:
    Sendable,
    Hashable
{
    case hidden
    case absolute
    case relative
    case hybrid
}

public struct TerminalLineNumberPresentation:
    Sendable,
    Hashable
{
    public var mode: TerminalLineNumberMode
    public var style: TerminalStyle
    public var currentStyle: TerminalStyle

    public init(
        mode: TerminalLineNumberMode = .hidden,
        style: TerminalStyle = .dim,
        currentStyle: TerminalStyle = .bold
    ) {
        self.mode = mode
        self.style = style
        self.currentStyle = currentStyle
    }

    public func gutterColumns(
        availableColumns: Int
    ) -> Int {
        guard mode != .hidden else {
            return 0
        }

        return min(
            7,
            max(
                0,
                availableColumns - 1
            )
        )
    }

    public func text(
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

        switch mode {
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

    public func style(
        sourceLineNumber: Int,
        currentLineNumber: Int
    ) -> TerminalStyle {
        sourceLineNumber == currentLineNumber
            ? currentStyle
            : style
    }
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
