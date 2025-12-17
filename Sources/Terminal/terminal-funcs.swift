import Foundation

public enum Terminal {
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
