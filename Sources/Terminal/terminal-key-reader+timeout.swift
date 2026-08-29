#if canImport(Darwin)
import Darwin
#endif

public extension TerminalKeyReader {
    func readEvent(
        timeoutMilliseconds: Int32
    ) -> TerminalInputEvent? {
        #if canImport(Darwin)
        var descriptor = pollfd(
            fd: fileDescriptor,
            events: Int16(POLLIN),
            revents: 0
        )

        while true {
            let status = poll(
                &descriptor,
                1,
                timeoutMilliseconds
            )

            if status > 0 {
                return readEvent()
            }

            if status == 0 {
                return nil
            }

            guard errno == EINTR else {
                return nil
            }
        }
        #else
        _ = timeoutMilliseconds
        return readEvent()
        #endif
    }

    func readKey(
        timeoutMilliseconds: Int32
    ) -> TerminalKey? {
        #if canImport(Darwin)
        var descriptor = pollfd(
            fd: fileDescriptor,
            events: Int16(POLLIN),
            revents: 0
        )

        while true {
            let status = poll(
                &descriptor,
                1,
                timeoutMilliseconds
            )

            if status > 0 {
                return readKey()
            }

            if status == 0 {
                return nil
            }

            guard errno == EINTR else {
                return nil
            }
        }
        #else
        _ = timeoutMilliseconds
        return readKey()
        #endif
    }
}
