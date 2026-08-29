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

    func readEvents(
        timeoutMilliseconds: Int32,
        maximumCount: Int = 64
    ) -> [TerminalInputEvent] {
        let maximumCount = max(
            0,
            maximumCount
        )

        guard maximumCount > 0,
              let first = readEvent(
                timeoutMilliseconds: timeoutMilliseconds
              ) else {
            return []
        }

        var events = [
            first,
        ]

        while events.count < maximumCount,
              let event = readEvent(
                timeoutMilliseconds: 0
              ) {
            events.append(
                event
            )
        }

        return events
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
