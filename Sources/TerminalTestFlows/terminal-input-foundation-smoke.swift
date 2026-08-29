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
        case unexpectedComposerPaste
        case unexpectedEventBatch
    }

    static func run() throws {
        try runComposerPasteProbe()

        guard TerminalSession.Options.interactive.useBracketedPaste else {
            throw Failure.unexpectedBracketedPasteSession
        }

        #if canImport(Darwin)
        try runUTF8Probe()
        try runPasteProbe()
        try runLegacyPasteProbe()
        try runEventBatchProbe()
        #endif
    }

    private static func runComposerPasteProbe() throws {
        var composer = TerminalTextInputControl()
        let paste = "one\r\ntwo\rthree"

        guard composer.handle(
            .paste(
                paste
            )
        ) == .changed,
        composer.input.text == "one\ntwo\nthree",
        composer.input.cursorOffset == composer.input.text.count else {
            throw Failure.unexpectedComposerPaste
        }

        var frame = TerminalFrame(
            rows: 1,
            columns: 40
        )

        composer.render(
            into: &frame,
            in: TerminalRegion(
                rows: 1,
                columns: 40
            ),
            isFocused: true
        )

        guard let rendered = frame.spans(
            inRow: 0
        ).first?.content,
        !rendered.contains(
            "\n"
        ),
        rendered.contains(
            "one↵two↵three"
        ),
        composer.handle(
            .key(
                .enter
            )
        ) == .submitRequested else {
            throw Failure.unexpectedComposerPaste
        }
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

    private static func runEventBatchProbe() throws {
        try withReader(
            bytes: Array(
                "jjkk".utf8
            )
        ) { reader in
            guard reader.readEvents(
                timeoutMilliseconds: 0,
                maximumCount: 3
            ) == [
                .key(.char("j")),
                .key(.char("j")),
                .key(.char("k")),
            ],
            reader.readEvents(
                timeoutMilliseconds: 0,
                maximumCount: 3
            ) == [
                .key(.char("k")),
            ],
            reader.readEvents(
                timeoutMilliseconds: 0,
                maximumCount: 3
            ).isEmpty else {
                throw Failure.unexpectedEventBatch
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
