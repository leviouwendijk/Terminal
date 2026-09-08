public struct TerminalYankPresentation:
    Sendable,
    Hashable
{
    public static let standardDurationNanoseconds: UInt64 =
        200_000_000

    public let sourceRanges: [Range<Int>]
    public let expiresAtNanoseconds: UInt64

    public init(
        sourceRange: Range<Int>,
        expiresAtNanoseconds: UInt64
    ) {
        self.init(
            sourceRanges: [
                sourceRange,
            ],
            expiresAtNanoseconds: expiresAtNanoseconds
        )
    }

    public init(
        sourceRanges: [Range<Int>],
        expiresAtNanoseconds: UInt64
    ) {
        self.sourceRanges = sourceRanges
        self.expiresAtNanoseconds = expiresAtNanoseconds
    }

    public var sourceRange: Range<Int> {
        sourceRanges.first
            ?? 0..<0
    }

    public func isActive(
        atNanoseconds now: UInt64
    ) -> Bool {
        now < expiresAtNanoseconds
    }
}

