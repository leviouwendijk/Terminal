import Darwin

public extension Terminal.IO.StandardInput {
    @discardableResult
    func reconnect(
        to source: Source
    ) -> Bool {
        switch source {
        case .terminal:
            return reconnectToTerminal()
        }
    }

    private func reconnectToTerminal() -> Bool {
        let descriptor = open(
            "/dev/tty",
            O_RDWR
        )

        guard descriptor >= 0 else {
            return false
        }

        defer {
            close(
                descriptor
            )
        }

        guard dup2(
            descriptor,
            STDIN_FILENO
        ) >= 0 else {
            return false
        }

        return isatty(
            STDIN_FILENO
        ) == 1
    }
}
