import Foundation

public enum TerminalTextWrap {
    public static func lines(
        _ text: String,
        width: Int
    ) -> [String] {
        let width = max(
            1,
            width
        )

        let normalized = text
            .replacingOccurrences(
                of: "\r\n",
                with: "\n"
            )
            .replacingOccurrences(
                of: "\r",
                with: "\n"
            )

        var out: [String] = []

        for rawLine in normalized.components(separatedBy: "\n") {
            out.append(
                contentsOf: wrapLine(
                    rawLine,
                    width: width
                )
            )
        }

        guard !out.isEmpty else {
            return [
                ""
            ]
        }

        return out
    }

    private static func wrapLine(
        _ line: String,
        width: Int
    ) -> [String] {
        guard line.count > width else {
            return [
                line
            ]
        }

        let words = line
            .split(
                separator: " ",
                omittingEmptySubsequences: true
            )
            .map(String.init)

        guard !words.isEmpty else {
            return [
                line
            ]
        }

        var out: [String] = []
        var current = ""

        for word in words {
            append(
                word: word,
                width: width,
                current: &current,
                out: &out
            )
        }

        if !current.isEmpty {
            out.append(
                current
            )
        }

        return out
    }

    private static func append(
        word: String,
        width: Int,
        current: inout String,
        out: inout [String]
    ) {
        if word.count > width {
            if !current.isEmpty {
                out.append(
                    current
                )
                current = ""
            }

            let chunks = chunk(
                word,
                width: width
            )

            guard let last = chunks.last else {
                return
            }

            out.append(
                contentsOf: chunks.dropLast()
            )

            current = last
            return
        }

        if current.isEmpty {
            current = word
            return
        }

        if current.count + 1 + word.count <= width {
            current += " " + word
            return
        }

        out.append(
            current
        )
        current = word
    }

    private static func chunk(
        _ text: String,
        width: Int
    ) -> [String] {
        var out: [String] = []
        var remaining = text[...]

        while remaining.count > width {
            let end = remaining.index(
                remaining.startIndex,
                offsetBy: width
            )

            out.append(
                String(
                    remaining[..<end]
                )
            )

            remaining = remaining[end...]
        }

        if !remaining.isEmpty {
            out.append(
                String(
                    remaining
                )
            )
        }

        return out
    }
}
