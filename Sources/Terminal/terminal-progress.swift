import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// One owner's native OSC 9;4 progress indicator on a selected terminal stream.
/// Call stop() when ownership ends; do not install multiple competing owners
/// for the same terminal stream. An application with concurrent jobs should
/// aggregate their state before updating this controller.
public actor TerminalProgress {
    public let stream: TerminalStream

    private let enabled: Bool
    private let refreshInterval: Duration
    private let output: @Sendable (String) -> Void
    private var state: ANSIProgress = .inactive
    private var refreshTask: Task<Void, Never>?
    private var generation: UInt64 = 0

    public init(
        stream: TerminalStream = .standardError,
        enabled: Bool = true,
        isTerminal: Bool? = nil,
        refreshInterval: Duration = .seconds(1),
        output: (@Sendable (String) -> Void)? = nil
    ) {
        self.stream = stream
        #if canImport(Darwin) || canImport(Glibc)
        let interactive = isTerminal ?? (isatty(stream.fileHandle.fileDescriptor) == 1)
        #else
        let interactive = isTerminal ?? false
        #endif
        self.enabled = enabled && interactive
        self.refreshInterval = refreshInterval > .zero ? refreshInterval : .seconds(1)
        self.output = output ?? { Terminal.write($0, to: stream) }
    }

    public func start(_ value: ANSIProgress = .indeterminate) {
        update(value)
    }

    public func update(_ value: ANSIProgress) {
        guard value != .inactive else {
            stop()
            return
        }
        guard enabled else { return }

        let changed = state != value
        state = value
        if changed { output(value.encoded()) }
        guard refreshTask == nil else { return }

        generation &+= 1
        let current = generation
        let interval = refreshInterval
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    break
                }
                await self?.refresh(generation: current)
            }
        }
    }

    public func stop() {
        let wasActive = state != .inactive
        generation &+= 1
        refreshTask?.cancel()
        refreshTask = nil
        state = .inactive
        if enabled && wasActive { output(ANSIProgress.inactive.encoded()) }
    }

    private func refresh(generation expected: UInt64) {
        guard enabled, generation == expected, state != .inactive else { return }
        output(state.encoded())
    }
}
