import Foundation

public struct TerminalLiveStatusLineFrame: Sendable, Hashable {
    public let elapsedSeconds: TimeInterval
    public let limitSeconds: TimeInterval?

    public init(
        elapsedSeconds: TimeInterval,
        limitSeconds: TimeInterval?
    ) {
        self.elapsedSeconds = elapsedSeconds
        self.limitSeconds = limitSeconds
    }

    public var remainingSeconds: TimeInterval? {
        guard let limitSeconds else {
            return nil
        }

        return max(
            0,
            limitSeconds - elapsedSeconds
        )
    }

    public var elapsedText: String {
        TerminalDurationFormatter.format(
            elapsedSeconds
        )
    }

    public var limitText: String? {
        guard let limitSeconds else {
            return nil
        }

        return TerminalDurationFormatter.format(
            limitSeconds
        )
    }

    public var remainingText: String? {
        guard let remainingSeconds else {
            return nil
        }

        return TerminalDurationFormatter.format(
            remainingSeconds
        )
    }
}

public enum TerminalDurationFormatter {
    public static func format(
        _ seconds: TimeInterval
    ) -> String {
        let centiseconds = max(
            0,
            Int(
                (seconds * 100).rounded(
                    .down
                )
            )
        )

        let hours = centiseconds / 360_000
        let minutes = (centiseconds % 360_000) / 6_000
        let wholeSeconds = (centiseconds % 6_000) / 100
        let fraction = centiseconds % 100

        if hours > 0 {
            return String(
                format: "%dh %dm %02d.%02ds",
                hours,
                minutes,
                wholeSeconds,
                fraction
            )
        }

        if minutes > 0 {
            return String(
                format: "%dm %02d.%02ds",
                minutes,
                wholeSeconds,
                fraction
            )
        }

        return String(
            format: "%d.%02ds",
            wholeSeconds,
            fraction
        )
    }
}

public actor TerminalLiveStatusLine {
    public typealias Renderer = @Sendable (
        TerminalLiveStatusLineFrame
    ) -> String

    private let stream: TerminalStream
    private let startedAt: Date
    private let limitSeconds: TimeInterval?
    private let refreshIntervalNanoseconds: UInt64
    private let renderer: Renderer

    private var task: Task<Void, Never>?

    public init(
        stream: TerminalStream = .standardError,
        limitSeconds: TimeInterval? = nil,
        refreshIntervalNanoseconds: UInt64 = 50_000_000,
        renderer: @escaping Renderer
    ) {
        self.stream = stream
        self.startedAt = Date()
        self.limitSeconds = limitSeconds
        self.refreshIntervalNanoseconds = refreshIntervalNanoseconds
        self.renderer = renderer
    }

    public func start() {
        guard task == nil else {
            return
        }

        let stream = self.stream
        let startedAt = self.startedAt
        let limitSeconds = self.limitSeconds
        let refreshIntervalNanoseconds = self.refreshIntervalNanoseconds
        let renderer = self.renderer

        Terminal.hideCursor(
            on: stream
        )

        task = Task.detached {
            while !Task.isCancelled {
                let frame = TerminalLiveStatusLineFrame(
                    elapsedSeconds: Date().timeIntervalSince(
                        startedAt
                    ),
                    limitSeconds: limitSeconds
                )

                Terminal.clearLine(
                    on: stream
                )
                Terminal.write(
                    renderer(
                        frame
                    ),
                    to: stream
                )
                Terminal.flush(
                    stream
                )

                try? await Task.sleep(
                    nanoseconds: refreshIntervalNanoseconds
                )
            }
        }
    }

    public func stop(
        finalLine: String? = nil
    ) {
        task?.cancel()
        task = nil

        Terminal.clearLine(
            on: stream
        )

        if let finalLine {
            Terminal.write(
                finalLine + "\n",
                to: stream
            )
        }

        Terminal.showCursor(
            on: stream
        )
        Terminal.flush(
            stream
        )
    }
}
