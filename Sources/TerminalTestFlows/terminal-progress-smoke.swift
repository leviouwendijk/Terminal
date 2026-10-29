import Foundation
import Terminal

private final class TerminalProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []

    func append(_ value: String) {
        lock.lock()
        defer { lock.unlock() }
        values.append(value)
    }

    func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}

enum TerminalProgressSmoke {
    static func run() async throws {
        let recorder = TerminalProgressRecorder()
        let progress = TerminalProgress(
            enabled: true,
            isTerminal: true,
            refreshInterval: .milliseconds(20),
            output: { recorder.append($0) }
        )
        await progress.start(.indeterminate)
        try await Task.sleep(for: .milliseconds(75))
        await progress.stop()
        let before = recorder.snapshot()
        guard before.count >= 3,
              before.first == ANSIProgress.indeterminate.encoded(),
              before.last == ANSIProgress.inactive.encoded() else {
            throw TerminalTestFailure(
                probe: "terminal-progress lifecycle",
                expectation: "start, refresh, clear",
                observed: "\(before)"
            )
        }
        try await Task.sleep(for: .milliseconds(60))
        guard recorder.snapshot() == before else {
            throw TerminalTestFailure(
                probe: "terminal-progress stale refresh",
                expectation: "no emission after stop",
                observed: "\(recorder.snapshot())"
            )
        }
        let disabledRecorder = TerminalProgressRecorder()
        let disabled = TerminalProgress(
            enabled: true,
            isTerminal: false,
            output: { disabledRecorder.append($0) }
        )
        await disabled.start(.indeterminate)
        await disabled.stop()
        guard disabledRecorder.snapshot().isEmpty else {
            throw TerminalTestFailure(
                probe: "terminal-progress non-TTY suppression",
                expectation: "no emission",
                observed: "\(disabledRecorder.snapshot())"
            )
        }
    }
}
