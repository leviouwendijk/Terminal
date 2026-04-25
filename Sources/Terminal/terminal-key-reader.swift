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
        #if canImport(Darwin)
        guard let firstByte = readByteBlocking() else {
            return .unknown([])
        }

        return decode(
            firstByte: firstByte
        )
        #else
        return .unknown([])
        #endif
    }

    #if canImport(Darwin)
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
            if let byte = readByteWithRawTimeout() {
                return byte
            }
        }
    }

    private func readByteWithRawTimeout() -> UInt8? {
        var byte: UInt8 = 0
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
