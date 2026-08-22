import Foundation

#if canImport(Darwin)
import Darwin
#endif

public enum TerminalSessionError: Error, Sendable, LocalizedError {
    case unsupportedPlatform
    case failedToReadTerminalAttributes(Int32)
    case failedToApplyTerminalAttributes(Int32)

    public var errorDescription: String? {
        switch self {
        case .unsupportedPlatform:
            return "Terminal raw sessions are not supported on this platform."

        case .failedToReadTerminalAttributes(let code):
            return "Failed to read terminal attributes. errno=\(code)"

        case .failedToApplyTerminalAttributes(let code):
            return "Failed to apply terminal attributes. errno=\(code)"
        }
    }
}

public final class TerminalSession: @unchecked Sendable {
    public struct Options: Sendable, Codable, Hashable {
        public var useAlternateScreen: Bool
        public var hideCursor: Bool
        public var useRawMode: Bool
        public var restoreOnInterrupt: Bool
        public var outputStream: TerminalStream

        public init(
            useAlternateScreen: Bool = false,
            hideCursor: Bool = false,
            useRawMode: Bool = false,
            restoreOnInterrupt: Bool = true,
            outputStream: TerminalStream = .standardError
        ) {
            self.useAlternateScreen = useAlternateScreen
            self.hideCursor = hideCursor
            self.useRawMode = useRawMode
            self.restoreOnInterrupt = restoreOnInterrupt
            self.outputStream = outputStream
        }

        public static let plain = Options()

        public static let interactive = Options(
            useAlternateScreen: true,
            hideCursor: true,
            useRawMode: true,
            restoreOnInterrupt: true,
            outputStream: .standardError
        )
    }

    public let options: Options

    #if canImport(Darwin)
    private let inputFileDescriptor: Int32
    private var savedAttributes: termios?
    private var previousInterruptAction: sigaction?
    private var interruptStateID: UInt64?
    private var isActive: Bool = false
    #endif

    public init(
        options: Options = .interactive
    ) throws {
        self.options = options

        #if canImport(Darwin)
        self.inputFileDescriptor = STDIN_FILENO
        try activate()
        #else
        throw TerminalSessionError.unsupportedPlatform
        #endif
    }

    deinit {
        restore()
    }

    public func restore() {
        #if canImport(Darwin)
        guard isActive else {
            return
        }

        if let savedAttributes {
            var restoredAttributes = savedAttributes
            tcsetattr(
                inputFileDescriptor,
                TCSANOW,
                &restoredAttributes
            )
        }

        if options.hideCursor {
            Terminal.showCursor(
                on: options.outputStream
            )
        }

        if options.useAlternateScreen {
            Terminal.leaveAlternateScreen(
                to: options.outputStream
            )
        }

        Terminal.flush(
            options.outputStream
        )

        if options.restoreOnInterrupt,
           var previousInterruptAction {
            sigaction(
                SIGINT,
                &previousInterruptAction,
                nil
            )
        }

        if let interruptStateID {
            _terminalSessionInterruptState.remove(
                interruptStateID
            )

            self.interruptStateID = nil
        }

        isActive = false
        #endif
    }

    #if canImport(Darwin)
    private func activate() throws {
        guard !isActive else {
            return
        }

        var attributes = termios()

        guard tcgetattr(
            inputFileDescriptor,
            &attributes
        ) == 0 else {
            throw TerminalSessionError.failedToReadTerminalAttributes(
                errno
            )
        }

        savedAttributes = attributes
        interruptStateID =
            _terminalSessionInterruptState.store(
                attributes,
                showCursorOnInterrupt: options.hideCursor,
                leaveAlternateScreenOnInterrupt:
                    options.useAlternateScreen
            )

        if options.useAlternateScreen {
            Terminal.enterAlternateScreen(
                to: options.outputStream
            )
        }

        if options.hideCursor {
            Terminal.hideCursor(
                on: options.outputStream
            )
        }

        if options.useRawMode {
            var interactiveAttributes = attributes

            interactiveAttributes.c_lflag &= ~tcflag_t(ECHO | ICANON)
            interactiveAttributes.c_lflag |= tcflag_t(ISIG)

            interactiveAttributes.c_iflag &= ~tcflag_t(IXON)

            interactiveAttributes.c_oflag |= tcflag_t(OPOST)

            #if os(macOS)
            interactiveAttributes.c_oflag |= tcflag_t(ONLCR)
            #endif

            withUnsafeMutablePointer(
                to: &interactiveAttributes.c_cc
            ) { controlCharactersPointer in
                controlCharactersPointer.withMemoryRebound(
                    to: cc_t.self,
                    capacity: Int(NCCS)
                ) { controlCharacters in
                    controlCharacters[Int(VMIN)] = 1
                    controlCharacters[Int(VTIME)] = 0
                }
            }

            guard tcsetattr(
                inputFileDescriptor,
                TCSANOW,
                &interactiveAttributes
            ) == 0 else {
                throw TerminalSessionError.failedToApplyTerminalAttributes(
                    errno
                )
            }
        }

        if options.restoreOnInterrupt {
            installInterruptHandler()
        }

        Terminal.flush(
            options.outputStream
        )

        isActive = true
    }

    private func installInterruptHandler() {
        var action = sigaction()
        sigemptyset(
            &action.sa_mask
        )
        action.sa_flags = 0
        action.__sigaction_u.__sa_handler = terminal_session_sigint_handler

        var previous = sigaction()

        sigaction(
            SIGINT,
            &action,
            &previous
        )

        previousInterruptAction = previous
    }
    #endif
}

#if canImport(Darwin)
private final class TerminalSessionInterruptState: @unchecked Sendable {
    private struct Entry {
        let id: UInt64
        let savedAttributes: termios
        let showCursorOnInterrupt: Bool
        let leaveAlternateScreenOnInterrupt: Bool
    }

    private var entries: [Entry] = []
    private var nextID: UInt64 = 1

    @discardableResult
    func store(
        _ attributes: termios,
        showCursorOnInterrupt: Bool,
        leaveAlternateScreenOnInterrupt: Bool
    ) -> UInt64 {
        let id = nextID

        nextID &+= 1

        if nextID == 0 {
            nextID = 1
        }

        entries.append(
            Entry(
                id: id,
                savedAttributes: attributes,
                showCursorOnInterrupt:
                    showCursorOnInterrupt,
                leaveAlternateScreenOnInterrupt:
                    leaveAlternateScreenOnInterrupt
            )
        )

        return id
    }

    func remove(
        _ id: UInt64
    ) {
        entries.removeAll {
            $0.id == id
        }
    }

    func restoreForInterrupt() {
        guard let outermost = entries.first else {
            return
        }

        var attributes =
            outermost.savedAttributes

        tcsetattr(
            STDIN_FILENO,
            TCSANOW,
            &attributes
        )

        let showCursorOnInterrupt =
            entries.contains {
                $0.showCursorOnInterrupt
            }

        let leaveAlternateScreenOnInterrupt =
            entries.contains {
                $0.leaveAlternateScreenOnInterrupt
            }

        var sequence = ""

        if showCursorOnInterrupt {
            sequence += "\u{001B}[?25h"
        }

        if leaveAlternateScreenOnInterrupt {
            sequence += "\u{001B}[?1049l"
        }

        guard !sequence.isEmpty else {
            return
        }

        sequence.withCString { pointer in
            _ = write(
                STDERR_FILENO,
                pointer,
                strlen(pointer)
            )
        }
    }
}

private let _terminalSessionInterruptState = TerminalSessionInterruptState()

@_cdecl("terminal_session_sigint_handler")
private func terminal_session_sigint_handler(
    _ signal: Int32
) {
    _terminalSessionInterruptState.restoreForInterrupt()
    _exit(
        128 + signal
    )
}
#endif
