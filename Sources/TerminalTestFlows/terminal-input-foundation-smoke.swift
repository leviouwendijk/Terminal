import Foundation
import Terminal

#if canImport(Darwin)
import Darwin
#endif

enum TerminalInputFoundationSmoke {
    enum Failure:
        Error
    {
        case pipeUnavailable
        case unexpectedUTF8
        case unexpectedPaste
        case unexpectedLegacyPaste
        case unexpectedBracketedPasteSession
    }

    static func run() throws {
        guard TerminalSession.Options.interactive.useBracketedPaste else {
            throw Failure.unexpectedBracketedPasteSession
        }

        #if canImport(Darwin)
        try runUTF8Probe()
        try runPasteProbe()
        try runLegacyPasteProbe()
        #endif
    }

    #if canImport(Darwin)
    private static func runUTF8Probe() throws {
        try withReader(
            bytes: Array(
                "é你🙂".utf8
            )
        ) { reader in
            guard reader.readEvent() == .key(
                .char("é")
            ),
            reader.readEvent() == .key(
                .char("你")
            ),
            reader.readEvent() == .key(
                .char("🙂")
            ) else {
                throw Failure.unexpectedUTF8
            }
        }
    }

    private static func runPasteProbe() throws {
        let content = "first\nλ🙂\nlast"
        let encoded =
            "\u{001B}[200~"
            + content
            + "\u{001B}[201~"

        try withReader(
            bytes: Array(
                encoded.utf8
            )
        ) { reader in
            guard reader.readEvent() == .paste(
                content
            ) else {
                throw Failure.unexpectedPaste
            }
        }
    }

    private static func runLegacyPasteProbe() throws {
        let content = "one\ntwo"
        let encoded =
            "\u{001B}[200~"
            + content
            + "\u{001B}[201~"

        try withReader(
            bytes: Array(
                encoded.utf8
            )
        ) { reader in
            guard reader.readKey() == .char(
                content
            ) else {
                throw Failure.unexpectedLegacyPaste
            }
        }
    }

    private static func withReader(
        bytes: [UInt8],
        _ body: (TerminalKeyReader) throws -> Void
    ) throws {
        var descriptors = [
            Int32(0),
            Int32(0),
        ]

        guard pipe(
            &descriptors
        ) == 0 else {
            throw Failure.pipeUnavailable
        }

        let readerDescriptor = descriptors[0]
        let writerDescriptor = descriptors[1]

        defer {
            close(
                readerDescriptor
            )
            close(
                writerDescriptor
            )
        }

        bytes.withUnsafeBytes { buffer in
            guard let address = buffer.baseAddress else {
                return
            }

            _ = Darwin.write(
                writerDescriptor,
                address,
                buffer.count
            )
        }

        try body(
            TerminalKeyReader(
                fileDescriptor: readerDescriptor
            )
        )
    }
    #endif
}
