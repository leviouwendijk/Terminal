import Foundation
import GhosttyVt

public enum GhosttyTerminalError: Error, Sendable {
    case invalid_size
    case initialization_failed
    case formatter_failed
    case invalid_utf8
}

/// A headless VT screen. Confine calls to one execution context.
/// This does not own a PTY or draw to the host terminal.
public final class GhosttyTerminalScreen {
    private let handle: GhosttyTerminal

    public init(columns: Int, rows: Int) throws {
        guard (1...Int(UInt16.max)).contains(columns),
              (1...Int(UInt16.max)).contains(rows) else {
            throw GhosttyTerminalError.invalid_size
        }

        var created: GhosttyTerminal?
        let result = ghostty_terminal_new(
            nil,
            &created,
            UInt16(columns),
            UInt16(rows)
        )
        guard result == GHOSTTY_SUCCESS, let created else {
            throw GhosttyTerminalError.initialization_failed
        }
        self.handle = created
    }

    deinit {
        ghostty_terminal_free(handle)
    }

    public func feed(_ bytes: Data) {
        bytes.withUnsafeBytes { raw in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else {
                return
            }
            ghostty_terminal_vt_write(handle, base, raw.count)
        }
    }

    public func feed(_ string: String) {
        feed(Data(string.utf8))
    }

    /// Plain-text snapshot of the emulated screen; not a live renderer.
    public func snapshot() throws -> String {
        var created: GhosttyFormatter?
        let result = ghostty_formatter_terminal_new(nil, &created, handle)
        guard result == GHOSTTY_SUCCESS, let formatter = created else {
            throw GhosttyTerminalError.formatter_failed
        }
        defer {
            ghostty_formatter_free(formatter)
        }

        var output: UnsafeMutablePointer<UInt8>?
        var length = 0
        let formatted = ghostty_formatter_format_alloc(
            formatter,
            nil,
            &output,
            &length
        )
        guard formatted == GHOSTTY_SUCCESS else {
            throw GhosttyTerminalError.formatter_failed
        }
        defer {
            ghostty_free(nil, output, length)
        }
        guard let output else {
            return ""
        }
        let data = Data(bytes: output, count: length)
        guard let value = String(data: data, encoding: .utf8) else {
            throw GhosttyTerminalError.invalid_utf8
        }
        return value
    }
}
