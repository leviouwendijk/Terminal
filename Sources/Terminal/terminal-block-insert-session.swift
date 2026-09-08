import Swim

public struct TerminalBlockInsertSession:
    Sendable,
    Codable,
    Hashable
{
    public let operation: Swim.BlockInsertOperation
    public let rows: [Int]
    public let insertionColumn: Int
    public let primaryRow: Int
    public private(set) var insertedText: String

    public init(
        operation: Swim.BlockInsertOperation,
        rows: [Int],
        insertionColumn: Int,
        primaryRow: Int,
        insertedText: String = ""
    ) {
        self.operation = operation
        self.rows = rows
        self.insertionColumn = max(
            0,
            insertionColumn
        )
        self.primaryRow = max(
            0,
            primaryRow
        )
        self.insertedText = insertedText
    }

    public mutating func append(
        _ text: String
    ) {
        insertedText += text
    }

    @discardableResult
    public mutating func removeLastCharacter() -> Bool {
        guard !insertedText.isEmpty else {
            return false
        }

        insertedText.removeLast()
        return true
    }
}
