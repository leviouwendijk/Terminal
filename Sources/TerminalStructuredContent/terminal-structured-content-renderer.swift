import DSL
import Terminal

public extension TerminalStructuredContent {
    struct Renderer: Sendable {
        public var format: Format

        public init(format: Format = .minimal) {
            self.format = format
        }

        public func rows(
            _ content: StructuredContent,
            columns: Int
        ) -> [String] {
            renderRows(content, columns: max(1, columns))
        }

        public func render(
            _ content: StructuredContent,
            columns: Int
        ) -> String {
            rows(content, columns: columns).joined(separator: "\n")
        }
    }
}

private extension TerminalStructuredContent.Renderer {
    struct StyledSource {
        var text = ""
        var spans: [TerminalTextStyleSpan] = []
        var pendingSpaceStyles: [TerminalStyle]?

        mutating func append(
            _ content: String,
            styles: [TerminalStyle]
        ) {
            for character in content {
                if character.isWhitespace {
                    if !text.isEmpty,
                       pendingSpaceStyles == nil {
                        pendingSpaceStyles = styles
                    }

                    continue
                }

                if let pendingSpaceStyles {
                    appendCharacter(
                        " ",
                        styles: pendingSpaceStyles
                    )
                    self.pendingSpaceStyles = nil
                }

                appendCharacter(
                    character,
                    styles: styles
                )
            }
        }

        private mutating func appendCharacter(
            _ character: Character,
            styles: [TerminalStyle]
        ) {
            let lower = text.count
            text.append(character)
            let upper = text.count

            for style in styles where !style.codes.isEmpty {
                if let index = spans.lastIndex(
                    where: {
                        $0.style == style
                            && $0.sourceRange.upperBound == lower
                    }
                ) {
                    spans[index].sourceRange =
                        spans[index].sourceRange.lowerBound..<upper
                } else {
                    spans.append(
                        .init(
                            sourceRange: lower..<upper,
                            style: style
                        )
                    )
                }
            }
        }
    }

    func renderRows(_ content: StructuredContent, columns: Int) -> [String] {
        switch content {
        case .collection(let children):
            return joined(
                children.map { renderRows($0, columns: columns) },
                spacing: format.block.collection.spacing
            )

        case .paragraph(let content):
            return inlineRows(
                content,
                columns: columns,
                baseStyle: format.block.paragraph.style
            )

        case .code(let language, let source):
            return codeRows(language: language, source: source, columns: columns)

        case .quote(let content):
            return quoteRows(content, columns: columns)

        case .list(let style, let items):
            return listRows(style: style, items: items, columns: columns)

        case .group(let role, let title, let content):
            return groupRows(
                role: role,
                title: title,
                content: content,
                columns: columns
            )
        }
    }

    func codeRows(language: String?, source: String, columns: Int) -> [String] {
        let style = format.block.code
        let indent = min(style.indent, max(0, columns - 1))
        let prefix = String(repeating: " ", count: indent)
        let sourceColumns = max(1, columns - indent)
        var rows: [String] = []

        if let language, !language.isEmpty {
            rows += displayRows(language, columns: columns).map(style.languageStyle.apply)
        }

        rows += logicalLines(source)
            .flatMap { displayRows($0, columns: sourceColumns) }
            .map { prefix + style.sourceStyle.apply($0) }

        return rows
    }

    func quoteRows(_ content: StructuredContent, columns: Int) -> [String] {
        let gutter = format.block.quote.gutter
        let gutterWidth = min(
            TerminalDisplay.width(of: gutter.text),
            max(0, columns - 1)
        )
        let gutterText = TerminalDisplay.clipped(gutter.text, columns: gutterWidth)
        let rows = renderRows(content, columns: max(1, columns - gutterWidth))

        guard !rows.isEmpty else { return [] }
        return rows.map { gutter.style.apply(gutterText) + $0 }
    }

    func listRows(
        style: StructuredContent.ListStyle,
        items: [StructuredContent],
        columns: Int
    ) -> [String] {
        var result: [String] = []

        for (index, item) in items.enumerated() {
            let marker: String

            switch style {
            case .unordered:
                marker = format.block.list.unordered.marker
            case .ordered:
                marker = "\(index + 1)" + format.block.list.ordered.suffix
            }

            let markerWidth = min(
                TerminalDisplay.width(of: marker),
                max(0, columns - 1)
            )
            let markerText = TerminalDisplay.clipped(marker, columns: markerWidth)
            let styledMarker = format.block.list.markerStyle.apply(markerText)
            let continuation = String(repeating: " ", count: markerWidth)
            let rows = renderRows(item, columns: max(1, columns - markerWidth))

            guard let first = rows.first else {
                result.append(styledMarker)
                continue
            }

            result.append(styledMarker + first)
            result += rows.dropFirst().map { continuation + $0 }
        }

        return result
    }

    func groupRows(
        role: StructuredContent.Role?,
        title: [StructuredContent.Inline]?,
        content: StructuredContent,
        columns: Int
    ) -> [String] {
        let group = format.block.group
        let presentation = group.roles.presentation(for: role) ?? group.standard
        let titleRows = resolvedTitle(title, presentation: presentation).map {
            inlineRows($0, columns: columns, baseStyle: presentation.titleStyle)
        } ?? []
        let indent = min(presentation.contentIndent, max(0, columns - 1))
        let contentRows = indented(
            renderRows(content, columns: max(1, columns - indent)),
            by: indent
        )

        if titleRows.isEmpty { return contentRows }
        if contentRows.isEmpty { return titleRows }
        return joined([titleRows, contentRows], spacing: presentation.spacing)
    }

    func resolvedTitle(
        _ title: [StructuredContent.Inline]?,
        presentation: TerminalStructuredContent.Format.Block.Group.Presentation
    ) -> [StructuredContent.Inline]? {
        let hasTitle = !(title?.isEmpty ?? true)

        guard let prefix = presentation.titlePrefix else {
            return hasTitle ? title : nil
        }

        guard hasTitle, let title else { return [.text(prefix)] }
        return [.text(prefix + presentation.titleSeparator)] + title
    }

    func inlineRows(
        _ content: [StructuredContent.Inline],
        columns: Int,
        baseStyle: TerminalStyle
    ) -> [String] {
        var source = StyledSource()
        append(content, to: &source, styles: [])
        return styledWordRows(source, columns: max(1, columns), baseStyle: baseStyle)
    }

    func append(
        _ content: [StructuredContent.Inline],
        to source: inout StyledSource,
        styles: [TerminalStyle]
    ) {
        for inline in content {
            switch inline {
            case .text(let text):
                source.append(text, styles: styles + [format.inline.text])
            case .code(let code):
                source.append(code, styles: styles + [format.inline.code])
            case .emphasis(let content):
                append(content, to: &source, styles: styles + [format.inline.emphasis])
            case .strong(let content):
                append(content, to: &source, styles: styles + [format.inline.strong])
            }
        }
    }

    func styledWordRows(
        _ source: StyledSource,
        columns: Int,
        baseStyle: TerminalStyle
    ) -> [String] {
        let characters = Array(source.text)
        let words = wordRanges(characters)
        guard !words.isEmpty else { return [] }

        var lines: [Range<Int>] = []
        var current: Range<Int>?

        for word in words {
            if TerminalDisplay.width(of: String(characters[word])) > columns {
                if let current { lines.append(current) }
                current = nil
                lines += split(word, characters: characters, columns: columns)
                continue
            }

            guard let existing = current else {
                current = word
                continue
            }

            let candidate = existing.lowerBound..<word.upperBound
            if TerminalDisplay.width(of: String(characters[candidate])) <= columns {
                current = candidate
            } else {
                lines.append(existing)
                current = word
            }
        }

        if let current { lines.append(current) }
        return lines.flatMap {
            renderedRange(
                $0,
                source: source,
                characters: characters,
                columns: columns,
                baseStyle: baseStyle
            )
        }
    }

    func renderedRange(
        _ range: Range<Int>,
        source: StyledSource,
        characters: [Character],
        columns: Int,
        baseStyle: TerminalStyle
    ) -> [String] {
        let spans = source.spans.compactMap { span -> TerminalTextStyleSpan? in
            let lower = max(range.lowerBound, span.sourceRange.lowerBound)
            let upper = min(range.upperBound, span.sourceRange.upperBound)
            guard lower < upper else { return nil }
            return .init(
                sourceRange: (lower - range.lowerBound)..<(upper - range.lowerBound),
                style: span.style
            )
        }

        return TerminalStyledText(
            text: String(characters[range]),
            style: baseStyle,
            spans: spans
        ).renderedRows(columns: columns)
    }

    func wordRanges(_ characters: [Character]) -> [Range<Int>] {
        var result: [Range<Int>] = []
        var start: Int?

        for (index, character) in characters.enumerated() {
            if character == " " {
                if let start { result.append(start..<index) }
                start = nil
            } else if start == nil {
                start = index
            }
        }

        if let start { result.append(start..<characters.count) }
        return result
    }

    func split(
        _ range: Range<Int>,
        characters: [Character],
        columns: Int
    ) -> [Range<Int>] {
        var result: [Range<Int>] = []
        var start = range.lowerBound
        var width = 0

        for index in range {
            let next = TerminalDisplay.width(of: String(characters[index]))
            if width > 0, width + next > columns {
                result.append(start..<index)
                start = index
                width = 0
            }
            width += next
        }

        if start < range.upperBound { result.append(start..<range.upperBound) }
        return result
    }

    func displayRows(_ text: String, columns: Int) -> [String] {
        guard !text.isEmpty else { return [""] }
        return TerminalTextLayout(text: text, columns: max(1, columns)).rows.map(\.content)
    }

    func logicalLines(_ text: String) -> [String] {
        guard !text.isEmpty else { return [""] }
        return text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }

    func indented(_ rows: [String], by amount: Int) -> [String] {
        guard amount > 0 else { return rows }
        let prefix = String(repeating: " ", count: amount)
        return rows.map { prefix + $0 }
    }

    func joined(_ blocks: [[String]], spacing: Int) -> [String] {
        let blocks = blocks.filter { !$0.isEmpty }
        guard !blocks.isEmpty else { return [] }
        let separator = Array(repeating: "", count: max(0, spacing))
        var result: [String] = []

        for (index, block) in blocks.enumerated() {
            if index > 0 { result += separator }
            result += block
        }

        return result
    }
}
