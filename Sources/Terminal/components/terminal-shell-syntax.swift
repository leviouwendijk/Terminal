import ANSI


/// Reads a POSIX-style command line for display: roles for colour, and
/// line breaks at pipes and lists. Display only; it never decides what runs.
public enum TerminalShellSyntax {
    public enum Role: String, Sendable, Hashable, CaseIterable {
        case command
        case option
        case argument
        case string
        case variable
        case assignment
        /// `|`, `&&`, `||`, `;`, `&`: where one command hands over to the next.
        case control
        case redirect
        case comment
        case space
    }

    public struct Token: Sendable, Hashable {
        public let text: String
        public let role: Role

        public init(_ text: String, _ role: Role) {
            self.text = text
            self.role = role
        }
    }

    public static func tokens(
        _ line: String
    ) -> [Token] {
        let characters = Array(line)
        var tokens: [Token] = []
        var index = 0
        var commandPosition = true

        func take(while predicate: (Character) -> Bool) -> String {
            let start = index
            while index < characters.count, predicate(characters[index]) { index += 1 }
            return String(characters[start..<index])
        }

        while index < characters.count {
            let character = characters[index]

            if character == " " || character == "\t" || character == "\n" {
                tokens.append(.init(take { $0 == " " || $0 == "\t" || $0 == "\n" }, .space))
                continue
            }

            if character == "#" {
                tokens.append(.init(String(characters[index...]), .comment))
                break
            }

            if let control = ["&&", "||", "|&", ";;", "|", ";", "&"].first(where: { matches($0, characters, at: index) }) {
                index += control.count
                tokens.append(.init(control, .control))
                commandPosition = true
                continue
            }

            if let redirect = ["2>&1", "&>>", "&>", "2>>", "2>", ">>", ">&", "<<<", "<<", ">", "<"]
                .first(where: { matches($0, characters, at: index) }) {
                index += redirect.count
                tokens.append(.init(redirect, .redirect))
                continue
            }

            // One shell word, quotes and substitutions included, split into
            // roles so `--path="$HOME/x"` keeps its parts readable.
            var parts: [Token] = []
            var plain = ""
            func flush() {
                if !plain.isEmpty { parts.append(.init(plain, .argument)); plain = "" }
            }
            while index < characters.count {
                let current = characters[index]
                if current == " " || current == "\t" || current == "\n" { break }
                if ["|", ";", "&", "<", ">"].contains(current) { break }
                if current == "'" || current == "\"" {
                    flush()
                    parts.append(.init(quoted(characters, &index), .string))
                    continue
                }
                if current == "$" {
                    flush()
                    parts.append(.init(substitution(characters, &index), .variable))
                    continue
                }
                if current == "\\", index + 1 < characters.count {
                    plain += String(characters[index...(index + 1)])
                    index += 2
                    continue
                }
                plain.append(current)
                index += 1
            }
            flush()

            let word = parts.map(\.text).joined()
            if commandPosition, isAssignment(word) {
                tokens += parts.enumerated().map { $0.offset == 0 ? .init($0.element.text, .assignment) : $0.element }
                continue
            }
            if commandPosition {
                tokens += parts.map { $0.role == .argument ? .init($0.text, .command) : $0 }
                commandPosition = false
                continue
            }
            if word.hasPrefix("-"), word.count > 1, let first = parts.first, first.role == .argument {
                tokens.append(.init(first.text, .option))
                tokens += parts.dropFirst()
                continue
            }
            tokens += parts
        }
        return tokens
    }

    public static func style(
        _ role: Role
    ) -> TerminalStyle {
        switch role {
        case .command: TerminalStyle(.bold)
        case .option: TerminalStyle(.cyan)
        case .string: TerminalStyle(.green)
        case .variable: TerminalStyle(.yellow)
        case .assignment: TerminalStyle(.blue)
        case .control, .redirect: TerminalStyle(.magenta)
        case .comment: TerminalStyle(.dim)
        case .argument, .space: .none
        }
    }

    /// Styled rows within `columns`. A line that fits stays one row; else
    /// each pipeline stage or listed command starts a row of its own, and a
    /// stage still too long wraps between words under a deeper indent.
    public static func rows(
        _ line: String,
        columns: Int
    ) -> [String] {
        let tokens = tokens(line)
        let width = max(8, columns)
        if TerminalDisplay.width(of: line) <= width, !line.contains("\n") {
            return [tokens.map(styled).joined()]
        }

        var stages: [[Token]] = [[]]
        for token in tokens {
            if token.role == .control, !(stages.last?.isEmpty ?? true) {
                stages.append([token])
            } else if token.role == .space, stages.last?.isEmpty ?? true {
                continue
            } else {
                stages[stages.count - 1].append(token)
            }
        }

        var rows: [String] = []
        for (number, stage) in stages.enumerated() where !stage.isEmpty {
            let lead = number == 0 ? "" : "  "
            var row = lead
            var used = lead.count
            for token in stage {
                let text = token.role == .space ? " " : token.text
                let size = TerminalDisplay.width(of: text)
                if token.role == .space {
                    if used + 1 >= width { continue }
                } else if used + size > width, used > lead.count + 4 {
                    rows.append(trimmedEnd(row))
                    row = lead + "    "
                    used = row.count
                }
                row += token.role == .space ? " " : styled(token)
                used += size
            }
            rows.append(trimmedEnd(row))
        }
        return rows
    }

    static func styled(_ token: Token) -> String {
        style(token.role).apply(token.text)
    }

    static func trimmedEnd(_ row: String) -> String {
        var row = row
        while row.hasSuffix(" ") { row.removeLast() }
        return row
    }

    static func matches(_ text: String, _ characters: [Character], at index: Int) -> Bool {
        let needle = Array(text)
        guard index + needle.count <= characters.count else { return false }
        return Array(characters[index..<(index + needle.count)]) == needle
    }

    static func quoted(_ characters: [Character], _ index: inout Int) -> String {
        let quote = characters[index]
        var text = String(quote)
        index += 1
        while index < characters.count {
            let current = characters[index]
            text.append(current)
            index += 1
            if current == "\\", quote == "\"", index < characters.count {
                text.append(characters[index])
                index += 1
                continue
            }
            if current == quote { break }
        }
        return text
    }

    static func substitution(_ characters: [Character], _ index: inout Int) -> String {
        var text = "$"
        index += 1
        guard index < characters.count else { return text }
        let open = characters[index]
        if open == "(" || open == "{" {
            let close: Character = open == "(" ? ")" : "}"
            var depth = 0
            while index < characters.count {
                let current = characters[index]
                text.append(current)
                index += 1
                if current == open { depth += 1 }
                if current == close { depth -= 1; if depth == 0 { break } }
            }
            return text
        }
        while index < characters.count,
              characters[index].isLetter || characters[index].isNumber || characters[index] == "_"
                || (text == "$" && "?#@*!$-".contains(characters[index])) {
            text.append(characters[index])
            index += 1
            if text.count == 2, "?#@*!$-".contains(text.last!) { break }
        }
        return text
    }

    static func isAssignment(_ word: String) -> Bool {
        guard let equals = word.firstIndex(of: "="), equals != word.startIndex else { return false }
        let name = word[..<equals]
        return name.first.map { $0.isLetter || $0 == "_" } == true
            && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}
