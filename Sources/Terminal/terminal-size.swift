import Foundation

#if canImport(Darwin)
import Darwin
#endif

public struct TerminalSize: Sendable, Codable, Hashable {
    public var columns: Int
    public var rows: Int

    public init(
        columns: Int,
        rows: Int
    ) {
        self.columns = max(
            1,
            columns
        )
        self.rows = max(
            1,
            rows
        )
    }
}

public extension Terminal {
    static func size(
        for stream: TerminalStream = .standardError
    ) -> TerminalSize {
        #if canImport(Darwin)
        var value = winsize()

        let descriptor: Int32

        switch stream {
        case .standardOutput:
            descriptor = STDOUT_FILENO

        case .standardError:
            descriptor = STDERR_FILENO
        }

        if ioctl(
            descriptor,
            TIOCGWINSZ,
            &value
        ) == 0 {
            let columns = Int(
                value.ws_col
            )
            let rows = Int(
                value.ws_row
            )

            if columns > 0,
               rows > 0 {
                return TerminalSize(
                    columns: columns,
                    rows: rows
                )
            }
        }
        #endif

        let columns = ProcessInfo.processInfo.environment["COLUMNS"]
            .flatMap(Int.init)
            ?? 80

        let rows = ProcessInfo.processInfo.environment["LINES"]
            .flatMap(Int.init)
            ?? 24

        return TerminalSize(
            columns: columns,
            rows: rows
        )
    }
}
