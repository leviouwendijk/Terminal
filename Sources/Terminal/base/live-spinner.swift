import Foundation

public actor LiveSpinner {
    private var task: Task<Void, Never>?

    public init() {}

    public func start(line: String) {
        guard task == nil else {
            return
        }

        Terminal.hideCursor()

        task = Task.detached {
            var spinner = TerminalSpinnerState()

            while !Task.isCancelled {
                Terminal.writeInline(
                    "\(spinner.currentFrame) \(line)"
                )
                spinner.advance()

                try? await Task.sleep(
                    nanoseconds: 90_000_000
                )
            }
        }
    }

    public func stop(replaceWith line: String) {
        task?.cancel()
        task = nil
        Terminal.writeInline(line + "\n")
        Terminal.showCursor()
    }
}
