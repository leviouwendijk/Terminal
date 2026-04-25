import Foundation

public enum TerminalStream: Sendable, Codable, Hashable {
    case standardOutput
    case standardError

    public var fileHandle: FileHandle {
        switch self {
        case .standardOutput:
            return .standardOutput

        case .standardError:
            return .standardError
        }
    }
}

public extension Terminal {
    @inline(__always)
    static func write(
        _ string: String,
        to stream: TerminalStream = .standardOutput
    ) {
        stream.fileHandle.write(
            Data(
                string.utf8
            )
        )
    }

    @inline(__always)
    static func flush(
        _ stream: TerminalStream = .standardOutput
    ) {
        switch stream {
        case .standardOutput:
            fflush(stdout)

        case .standardError:
            fflush(stderr)
        }
    }

    @inline(__always)
    static func enterAlternateScreen(
        to stream: TerminalStream = .standardError
    ) {
        write(
            "\u{001B}[?1049h",
            to: stream
        )
    }

    @inline(__always)
    static func leaveAlternateScreen(
        to stream: TerminalStream = .standardError
    ) {
        write(
            "\u{001B}[?1049l",
            to: stream
        )
    }

    @inline(__always)
    static func hideCursor(
        on stream: TerminalStream
    ) {
        write(
            "\u{001B}[?25l",
            to: stream
        )
    }

    @inline(__always)
    static func showCursor(
        on stream: TerminalStream
    ) {
        write(
            "\u{001B}[?25h",
            to: stream
        )
    }

    @inline(__always)
    static func clearScreen(
        to stream: TerminalStream = .standardError
    ) {
        write(
            ANSIColor.clearScreen.rawValue,
            to: stream
        )
    }

    @inline(__always)
    static func clearLine(
        on stream: TerminalStream
    ) {
        write(
            ANSIColor.clearLine.rawValue,
            to: stream
        )
        write(
            ANSIColor.cursorLeft.rawValue.replacingOccurrences(
                of: "{n}",
                with: "999"
            ),
            to: stream
        )
    }

    @inline(__always)
    static func moveCursor(
        line: Int,
        column: Int,
        to stream: TerminalStream = .standardError
    ) {
        let sequence = ANSIColor.cursorPosition.rawValue
            .replacingOccurrences(
                of: "{line}",
                with: "\(max(1, line))"
            )
            .replacingOccurrences(
                of: "{column}",
                with: "\(max(1, column))"
            )

        write(
            sequence,
            to: stream
        )
    }
}
