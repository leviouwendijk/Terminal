import Foundation

public actor LiveSpinner {
    private let frames = ["⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏"]
    private var index: Int = 0
    private var task: Task<Void, Never>?

    public init() {}

    public func start(line: String) {
        guard task == nil else { return }

        Terminal.hideCursor()

        let frames = self.frames

        task = Task.detached { [frames] in
            var i = 0
            while !Task.isCancelled {
                let frame = frames[i % frames.count]
                i += 1
                Terminal.writeInline("\(frame) \(line)")
                try? await Task.sleep(nanoseconds: 90_000_000)
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
