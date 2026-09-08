import Foundation

public struct TerminalInputBufferID:
    Sendable,
    Codable,
    Hashable,
    CustomStringConvertible
{
    public let rawValue: UUID

    public init(
        _ rawValue: UUID = UUID()
    ) {
        self.rawValue = rawValue
    }

    public var description: String {
        rawValue.uuidString.lowercased()
    }
}

public struct TerminalInputBufferStore:
    Sendable
{
    public var directory: URL

    public init(
        directory: URL = URL(
            fileURLWithPath: "/tmp/agentic/inputbuffers",
            isDirectory: true
        )
    ) {
        self.directory = directory
    }

    public func url(
        for id: TerminalInputBufferID
    ) -> URL {
        directory.appendingPathComponent(
            id.description + ".txt",
            isDirectory: false
        )
    }

    @discardableResult
    public func write(
        _ text: String,
        id: TerminalInputBufferID
    ) throws -> URL {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let destination = url(
            for: id
        )

        try text.write(
            to: destination,
            atomically: true,
            encoding: .utf8
        )

        return destination
    }
}
