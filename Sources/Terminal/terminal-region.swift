public struct TerminalInsets:
    Sendable,
    Codable,
    Hashable
{
    public var top: Int
    public var leading: Int
    public var bottom: Int
    public var trailing: Int

    public init(
        top: Int = 0,
        leading: Int = 0,
        bottom: Int = 0,
        trailing: Int = 0
    ) {
        self.top = max(
            0,
            top
        )
        self.leading = max(
            0,
            leading
        )
        self.bottom = max(
            0,
            bottom
        )
        self.trailing = max(
            0,
            trailing
        )
    }

    public init(
        vertical: Int,
        horizontal: Int
    ) {
        self.init(
            top: vertical,
            leading: horizontal,
            bottom: vertical,
            trailing: horizontal
        )
    }

    public static let zero = TerminalInsets()
}

public struct TerminalRegion:
    Sendable,
    Codable,
    Hashable
{
    public var top: Int
    public var leading: Int
    public var rows: Int
    public var columns: Int

    public init(
        top: Int = 0,
        leading: Int = 0,
        rows: Int,
        columns: Int
    ) {
        self.top = max(
            0,
            top
        )
        self.leading = max(
            0,
            leading
        )
        self.rows = max(
            0,
            rows
        )
        self.columns = max(
            0,
            columns
        )
    }

    public var bottom: Int {
        top + rows
    }

    public var trailing: Int {
        leading + columns
    }

    public var isEmpty: Bool {
        rows == 0
            || columns == 0
    }

    public func inset(
        by insets: TerminalInsets
    ) -> TerminalRegion {
        let topInset = min(
            rows,
            insets.top
        )
        let remainingRows = rows - topInset
        let bottomInset = min(
            remainingRows,
            insets.bottom
        )

        let leadingInset = min(
            columns,
            insets.leading
        )
        let remainingColumns = columns - leadingInset
        let trailingInset = min(
            remainingColumns,
            insets.trailing
        )

        return TerminalRegion(
            top: top + topInset,
            leading: leading + leadingInset,
            rows:
                rows
                - topInset
                - bottomInset,
            columns:
                columns
                - leadingInset
                - trailingInset
        )
    }
}
