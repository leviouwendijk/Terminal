#if canImport(Darwin)
import Darwin
#endif

public enum TerminalDisplay {
    public static func width(
        of text: String
    ) -> Int {
        if isSimpleASCII(
            text
        ) {
            return text.utf8.count
        }

        var width = 0
        var index = text.startIndex

        while index < text.endIndex {
            if isEscape(
                text[index]
            ) {
                index = endOfEscapeSequence(
                    in: text,
                    from: index
                )
                continue
            }

            let next = text.index(
                after: index
            )

            width += characterWidth(
                text[index]
            )
            index = next
        }

        return width
    }

    public static func clipped(
        _ text: String,
        columns: Int
    ) -> String {
        let columns = max(
            0,
            columns
        )

        guard columns > 0 else {
            return ""
        }

        if isSimpleASCII(
            text
        ) {
            guard text.utf8.count > columns else {
                return text
            }

            let end = text.index(
                text.startIndex,
                offsetBy: columns
            )

            return String(
                text[..<end]
            )
        }

        var result = ""
        var width = 0
        var index = text.startIndex
        var didClip = false
        var containsEscape = false

        while index < text.endIndex {
            if isEscape(
                text[index]
            ) {
                containsEscape = true

                let end = endOfEscapeSequence(
                    in: text,
                    from: index
                )

                result += String(
                    text[index..<end]
                )
                index = end
                continue
            }

            let character = text[index]
            let characterWidth = characterWidth(
                character
            )

            if width + characterWidth > columns {
                didClip = true
                break
            }

            result.append(
                character
            )
            width += characterWidth
            index = text.index(
                after: index
            )
        }

        if didClip,
           containsEscape
        {
            result += ANSIColor.reset.rawValue
        }

        return result
    }

    public static func slice(
        _ text: String,
        columns requestedRange: Range<Int>
    ) -> String {
        let lowerBound = max(
            0,
            requestedRange.lowerBound
        )
        let upperBound = max(
            lowerBound,
            requestedRange.upperBound
        )

        guard upperBound > lowerBound else {
            return ""
        }

        let requestedColumns =
            upperBound
            - lowerBound

        if isSimpleASCII(
            text
        ) {
            let count = text.utf8.count
            let start = min(
                lowerBound,
                count
            )
            let end = min(
                upperBound,
                count
            )
            let startIndex = text.index(
                text.startIndex,
                offsetBy: start
            )
            let endIndex = text.index(
                startIndex,
                offsetBy: end - start
            )
            let visible = String(
                text[startIndex..<endIndex]
            )

            return visible
                + String(
                    repeating: " ",
                    count:
                        requestedColumns
                        - (end - start)
                )
        }

        if lowerBound == 0 {
            return fitted(
                text,
                columns: requestedColumns
            )
        }

        var result = ""
        var prefix = ""
        var displayColumn = 0
        var outputColumn = 0
        var index = text.startIndex
        var didStart = false
        var containsEscape = false
        var containsOSC = false

        while index < text.endIndex {
            if isEscape(
                text[index]
            ) {
                let end = endOfEscapeSequence(
                    in: text,
                    from: index
                )
                let sequence = String(
                    text[index..<end]
                )

                containsEscape = true

                if sequence.hasPrefix(
                    "\u{001B}]"
                ) {
                    containsOSC = true
                }

                if displayColumn < lowerBound {
                    prefix += sequence
                } else if displayColumn < upperBound {
                    if !didStart {
                        result += prefix
                        didStart = true
                    }

                    result += sequence
                }

                index = end
                continue
            }

            let character = text[index]
            let next = text.index(
                after: index
            )
            let width = characterWidth(
                character
            )
            let characterStart = displayColumn
            let characterEnd = displayColumn + width

            if characterEnd <= lowerBound {
                displayColumn = characterEnd
                index = next
                continue
            }

            if characterStart >= upperBound {
                break
            }

            if !didStart {
                result += prefix
                didStart = true
            }

            let visibleStart = max(
                characterStart,
                lowerBound
            )
            let visibleEnd = min(
                characterEnd,
                upperBound
            )
            let visibleWidth = max(
                0,
                visibleEnd - visibleStart
            )
            let targetColumn =
                visibleStart
                - lowerBound

            if targetColumn > outputColumn {
                result += String(
                    repeating: " ",
                    count:
                        targetColumn
                        - outputColumn
                )
                outputColumn = targetColumn
            }

            if characterStart >= lowerBound,
               characterEnd <= upperBound {
                result.append(
                    character
                )
            } else {
                result += String(
                    repeating: " ",
                    count: visibleWidth
                )
            }

            outputColumn += visibleWidth
            displayColumn = characterEnd
            index = next
        }

        if outputColumn < requestedColumns {
            result += String(
                repeating: " ",
                count:
                    requestedColumns
                    - outputColumn
            )
        }

        if containsOSC {
            result += "\u{001B}]8;;\u{0007}"
        }

        if containsEscape {
            result += ANSIColor.reset.rawValue
        }

        return result
    }

    public static func fitted(
        _ text: String,
        columns: Int
    ) -> String {
        let columns = max(
            0,
            columns
        )

        guard columns > 0 else {
            return ""
        }

        if isSimpleASCII(
            text
        ) {
            let count = text.utf8.count

            if count >= columns {
                let end = text.index(
                    text.startIndex,
                    offsetBy: columns
                )

                return String(
                    text[..<end]
                )
            }

            return text
                + String(
                    repeating: " ",
                    count: columns - count
                )
        }

        let clipped = clipped(
            text,
            columns: columns
        )
        let remaining = max(
            0,
            columns - width(
                of: clipped
            )
        )

        return clipped
            + String(
                repeating: " ",
                count: remaining
            )
    }

    private static func isSimpleASCII(
        _ text: String
    ) -> Bool {
        text.utf8.allSatisfy {
            byte in

            byte >= 0x20
                && byte <= 0x7E
        }
    }

    private static func characterWidth(
        _ character: Character
    ) -> Int {
        if usesEmojiPresentation(
            character
        ) {
            return 2
        }

        #if canImport(Darwin)
        let width = character.unicodeScalars.reduce(
            0
        ) {
            total,
            scalar in

            let scalarWidth = wcwidth(
                wchar_t(
                    scalar.value
                )
            )

            if scalarWidth >= 0 {
                return total + Int(
                    scalarWidth
                )
            }

            return total + fallbackWidth(
                for: scalar
            )
        }

        return min(
            2,
            width
        )
        #else
        return character.isASCII
            ? 1
            : 1
        #endif
    }

    private static func usesEmojiPresentation(
        _ character: Character
    ) -> Bool {
        character.unicodeScalars.contains {
            scalar in

            scalar.properties.isEmojiPresentation
                || scalar.value == 0xFE0F
        }
    }

    #if canImport(Darwin)
    private static func fallbackWidth(
        for scalar: Unicode.Scalar
    ) -> Int {
        switch scalar.properties.generalCategory {
        case .control,
             .format,
             .nonspacingMark,
             .enclosingMark:
            return 0

        default:
            return 1
        }
    }
    #endif

    private static func isEscape(
        _ character: Character
    ) -> Bool {
        character.unicodeScalars.count == 1
            && character.unicodeScalars.first?.value == 0x1B
    }

    private static func endOfEscapeSequence(
        in text: String,
        from start: String.Index
    ) -> String.Index {
        var index = text.index(
            after: start
        )

        guard index < text.endIndex else {
            return index
        }

        let introducer = text[index]

        if introducer == "[" {
            index = text.index(
                after: index
            )

            while index < text.endIndex {
                let character = text[index]

                if isCSIFinal(
                    character
                ) {
                    return text.index(
                        after: index
                    )
                }

                index = text.index(
                    after: index
                )
            }

            return text.endIndex
        }

        if introducer == "]" {
            index = text.index(
                after: index
            )

            while index < text.endIndex {
                let character = text[index]

                if character.unicodeScalars.count == 1,
                   character.unicodeScalars.first?.value == 0x07
                {
                    return text.index(
                        after: index
                    )
                }

                if isEscape(
                    character
                ) {
                    let next = text.index(
                        after: index
                    )

                    if next < text.endIndex,
                       text[next] == "\\"
                    {
                        return text.index(
                            after: next
                        )
                    }
                }

                index = text.index(
                    after: index
                )
            }

            return text.endIndex
        }

        return text.index(
            after: index
        )
    }

    private static func isCSIFinal(
        _ character: Character
    ) -> Bool {
        guard character.unicodeScalars.count == 1,
              let scalar = character.unicodeScalars.first else {
            return false
        }

        return scalar.value >= 0x40
            && scalar.value <= 0x7E
    }
}

private extension Character {
    var isASCII: Bool {
        unicodeScalars.count == 1
            && unicodeScalars.first?.isASCII == true
    }
}
