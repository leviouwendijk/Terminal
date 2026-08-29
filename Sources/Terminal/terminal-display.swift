#if canImport(Darwin)
import Darwin
#endif

public enum TerminalDisplay {
    public static func width(
        of text: String
    ) -> Int {
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

    private static func characterWidth(
        _ character: Character
    ) -> Int {
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

            return total + max(
                0,
                Int(
                    scalarWidth
                )
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
