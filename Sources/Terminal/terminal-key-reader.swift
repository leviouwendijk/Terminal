import Foundation

#if canImport(Darwin)
import Darwin
#endif

public struct TerminalKeyReader: Sendable {
    #if canImport(Darwin)
    public let fileDescriptor: Int32
    #endif

    public init() {
        #if canImport(Darwin)
        self.fileDescriptor = STDIN_FILENO
        #endif
    }

    #if canImport(Darwin)
    public init(
        fileDescriptor: Int32
    ) {
        self.fileDescriptor = fileDescriptor
    }
    #endif

    public func readKey() -> TerminalKey {
        readEvent().legacyKey
    }

    public func readEvent() -> TerminalInputEvent {
        #if canImport(Darwin)
        guard let firstByte = readByteBlocking() else {
            return .key(
                .unknown([])
            )
        }

        return decodeEvent(
            firstByte: firstByte
        )
        #else
        return .key(
            .unknown([])
        )
        #endif
    }

    #if canImport(Darwin)
    private func decodeEvent(
        firstByte: UInt8
    ) -> TerminalInputEvent {
        if firstByte == 0x1B {
            return readEscapeEvent()
        }

        if firstByte >= 0x80 {
            return .key(
                readUTF8Character(
                    firstByte: firstByte
                )
            )
        }

        return .key(
            decode(
                firstByte: firstByte
            )
        )
    }

    private func readEscapeEvent() -> TerminalInputEvent {
        guard let secondByte = readByteWithRawTimeout() else {
            return .key(
                .escape
            )
        }

        switch secondByte {
        case 0x5B:
            return readCSIEvent()

        case 0x4F:
            return .key(
                readSS3Sequence()
            )

        default:
            return .key(
                .unknown(
                    [
                        0x1B,
                        secondByte,
                    ]
                )
            )
        }
    }

    private func readCSIEvent() -> TerminalInputEvent {
        guard let sequence = readCSIBytes() else {
            return .key(
                .unknown(
                    [
                        0x1B,
                        0x5B,
                    ]
                )
            )
        }

        if sequence == Array(
            "200~".utf8
        ) {
            return .paste(
                readBracketedPaste()
            )
        }

        return .key(
            decodeCSIBytes(
                sequence
            )
        )
    }

    private func readCSIBytes() -> [UInt8]? {
        var bytes: [UInt8] = []

        for _ in 0..<32 {
            guard let byte = readByteWithRawTimeout() else {
                return nil
            }

            bytes.append(
                byte
            )

            if byte >= 0x40,
               byte <= 0x7E {
                return bytes
            }
        }

        return bytes
    }

    private func decodeCSIBytes(
        _ bytes: [UInt8]
    ) -> TerminalKey {
        switch String(
            decoding: bytes,
            as: UTF8.self
        ) {
        case "A":
            return .up

        case "B":
            return .down

        case "C":
            return .right

        case "D":
            return .left

        case "H",
             "1~",
             "7~":
            return .home

        case "F",
             "4~",
             "8~":
            return .end

        case "2~":
            return .insert

        case "3~":
            return .delete

        case "5~":
            return .pageUp

        case "6~":
            return .pageDown

        default:
            return .unknown(
                [
                    0x1B,
                    0x5B,
                ] + bytes
            )
        }
    }

    private func readUTF8Character(
        firstByte: UInt8
    ) -> TerminalKey {
        let byteCount: Int

        switch firstByte {
        case 0xC2...0xDF:
            byteCount = 2

        case 0xE0...0xEF:
            byteCount = 3

        case 0xF0...0xF4:
            byteCount = 4

        default:
            return .unknown(
                [
                    firstByte,
                ]
            )
        }

        var bytes = [
            firstByte,
        ]

        for _ in 1..<byteCount {
            guard let byte = readByteWithRawTimeout() else {
                return .unknown(
                    bytes
                )
            }

            bytes.append(
                byte
            )

            guard byte & 0xC0 == 0x80 else {
                return .unknown(
                    bytes
                )
            }
        }

        guard let text = String(
            bytes: bytes,
            encoding: .utf8
        ) else {
            return .unknown(
                bytes
            )
        }

        return .char(
            text
        )
    }

    private func readBracketedPaste() -> String {
        let terminator = Array(
            "\u{001B}[201~".utf8
        )
        var content: [UInt8] = []
        var pending: [UInt8] = []

        while let byte = readByteBlocking() {
            pending.append(
                byte
            )

            while !terminator.starts(
                with: pending
            ) {
                content.append(
                    pending.removeFirst()
                )
            }

            if pending == terminator {
                pending.removeAll()
                break
            }
        }

        content.append(
            contentsOf: pending
        )

        return String(
            decoding: content,
            as: UTF8.self
        )
    }

    private func decode(
        firstByte: UInt8
    ) -> TerminalKey {
        switch firstByte {
        case 0x00:
            return .controlSpace

        case 0x03:
            return .control("C")

        case 0x04:
            return .control("D")

        case 0x09:
            return .tab

        case 0x0D, 0x0A:
            return .enter

        case 0x1B:
            return readEscapeSequence()

        case 0x20:
            return .space

        case 0x7F, 0x08:
            return .backspace

        case 0x01...0x1A:
            let scalarValue = UInt32(firstByte + 0x40)

            if let scalar = UnicodeScalar(scalarValue) {
                return .control(
                    String(scalar)
                )
            }

            return .unknown(
                [
                    firstByte
                ]
            )

        case 0x20...0x7E:
            if let scalar = UnicodeScalar(UInt32(firstByte)) {
                return .char(
                    String(scalar)
                )
            }

            return .unknown(
                [
                    firstByte
                ]
            )

        default:
            return .unknown(
                [
                    firstByte
                ]
            )
        }
    }

    private func readEscapeSequence() -> TerminalKey {
        guard let secondByte = readByteWithRawTimeout() else {
            return .escape
        }

        switch secondByte {
        case 0x5B:
            return readCSISequence()

        case 0x4F:
            return readSS3Sequence()

        default:
            return .unknown(
                [
                    0x1B,
                    secondByte
                ]
            )
        }
    }

    private func readCSISequence() -> TerminalKey {
        guard let thirdByte = readByteWithRawTimeout() else {
            return .unknown(
                [
                    0x1B,
                    0x5B
                ]
            )
        }

        switch thirdByte {
        case 0x41:
            return .up

        case 0x42:
            return .down

        case 0x43:
            return .right

        case 0x44:
            return .left

        case 0x48:
            return .home

        case 0x46:
            return .end

        case 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38:
            guard let terminator = readByteWithRawTimeout() else {
                return .unknown(
                    [
                        0x1B,
                        0x5B,
                        thirdByte
                    ]
                )
            }

            guard terminator == 0x7E else {
                return .unknown(
                    [
                        0x1B,
                        0x5B,
                        thirdByte,
                        terminator
                    ]
                )
            }

            switch thirdByte {
            case 0x31, 0x37:
                return .home

            case 0x32:
                return .insert

            case 0x33:
                return .delete

            case 0x34, 0x38:
                return .end

            case 0x35:
                return .pageUp

            case 0x36:
                return .pageDown

            default:
                return .unknown(
                    [
                        0x1B,
                        0x5B,
                        thirdByte,
                        terminator
                    ]
                )
            }

        default:
            return .unknown(
                [
                    0x1B,
                    0x5B,
                    thirdByte
                ]
            )
        }
    }

    private func readSS3Sequence() -> TerminalKey {
        guard let thirdByte = readByteWithRawTimeout() else {
            return .unknown(
                [
                    0x1B,
                    0x4F
                ]
            )
        }

        switch thirdByte {
        case 0x41:
            return .up

        case 0x42:
            return .down

        case 0x43:
            return .right

        case 0x44:
            return .left

        case 0x48:
            return .home

        case 0x46:
            return .end

        default:
            return .unknown(
                [
                    0x1B,
                    0x4F,
                    thirdByte
                ]
            )
        }
    }

    private func readByteBlocking() -> UInt8? {
        while true {
            if let byte = readByte() {
                return byte
            }

            guard errno == EINTR else {
                return nil
            }
        }
    }

    private func readByteWithRawTimeout() -> UInt8? {
        var descriptor = pollfd(
            fd: fileDescriptor,
            events: Int16(POLLIN),
            revents: 0
        )

        while true {
            let status = poll(
                &descriptor,
                1,
                25
            )

            if status > 0 {
                return readByte()
            }

            if status == 0 {
                return nil
            }

            guard errno == EINTR else {
                return nil
            }
        }
    }

    private func readByte() -> UInt8? {
        var byte: UInt8 = 0
        errno = 0

        let count = read(
            fileDescriptor,
            &byte,
            1
        )

        guard count == 1 else {
            return nil
        }

        return byte
    }
    #endif
}
