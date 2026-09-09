import Foundation
import Terminal

enum TerminalInputBufferStoreFoundationSmoke {
    static func run() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "terminal-input-buffer-store-\(UUID().uuidString)",
                isDirectory: true
            )

        defer {
            try? FileManager.default.removeItem(
                at: directory
            )
        }

        let store = TerminalInputBufferStore(
            directory: directory
        )
        let id = TerminalInputBufferID()
        let text = "hello\nworld"
        let destination = try store.write(
            text,
            id: id
        )
        let loaded = try String(
            contentsOf: destination,
            encoding: .utf8
        )

        guard loaded == text,
              destination.lastPathComponent
                == id.description + ".txt" else {
            throw TerminalTestFailure(
                probe: "TerminalInputBufferStore persistence",
                expectation: "stable id path with exact saved text",
                observed: "\(destination.path) -> \(loaded)"
            )
        }
    }
}
