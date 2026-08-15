#if canImport(Darwin)
import Darwin
#endif

public extension Terminal {
    static var isInteractive: Bool {
        #if canImport(Darwin)
        return isatty(
            STDIN_FILENO
        ) != 0
        #else
        return false
        #endif
    }
}
