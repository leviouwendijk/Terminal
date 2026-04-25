import Foundation

extension Terminal {
    @inline(__always)
    public static func clearLine() {
        FileHandle.standardOutput.write(Data(ANSIColor.clearLine.rawValue.utf8))
        FileHandle.standardOutput.write(Data(ANSIColor.cursorLeft.rawValue.replacingOccurrences(of: "{n}", with: "999").utf8))
    }

    @inline(__always)
    public static func hideCursor() {
        FileHandle.standardOutput.write(Data("\u{001B}[?25l".utf8))
    }

    @inline(__always)
    public static func showCursor() {
        FileHandle.standardOutput.write(Data("\u{001B}[?25h".utf8))
    }

    @inline(__always)
    public static func writeInline(_ s: String) {
        Terminal.clearLine()
        FileHandle.standardOutput.write(Data(s.utf8))
    }
}


extension Terminal {
    public enum ConfirmDefault: Sendable {
        case yes
        case no
    }

    @discardableResult
    public static func confirm(
        _ prompt: String,
        default defaultChoice: ConfirmDefault = .no
    ) -> Bool {
        let defaultIsYes: Bool
        let suffix: String

        switch defaultChoice {
        case .yes:
            defaultIsYes = true
            suffix = " [Y/n] "
        case .no:
            defaultIsYes = false
            suffix = " [y/N] "
        }

        fputs(prompt + suffix, stdout)
        fflush(stdout)

        let raw = readLine()?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        switch raw {
        case "":
            return defaultIsYes
        case "y", "yes":
            return true
        case "n", "no":
            return false
        default:
            return defaultIsYes
        }
    }

    @discardableResult
    public static func confirm(
        _ prompt: String,
        default defaultChoice: ConfirmDefault = .no,
        onYes: () throws -> Void,
        onNo: () throws -> Void
    ) rethrows -> Bool {
        let decision = confirm(prompt, default: defaultChoice)

        if decision {
            try onYes()
        } else {
            try onNo()
        }

        return decision
    }
}
