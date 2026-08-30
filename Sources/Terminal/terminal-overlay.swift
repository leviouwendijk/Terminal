public enum TerminalOverlayPlacement:
    Sendable,
    Hashable
{
    case centered(
        columns: Int,
        rows: Int
    )

    case trailing(
        columns: Int
    )
}

public struct TerminalOverlayStyle:
    Sendable,
    Hashable
{
    public var border: TerminalStyle
    public var title: TerminalStyle

    public init(
        border: TerminalStyle = .dim,
        title: TerminalStyle = .bold
    ) {
        self.border = border
        self.title = title
    }

    public static let standard = TerminalOverlayStyle()
}

public struct TerminalOverlay:
    Sendable,
    Hashable
{
    public var placement: TerminalOverlayPlacement
    public var outerInsets: TerminalInsets
    public var contentInsets: TerminalInsets
    public var style: TerminalOverlayStyle

    public init(
        placement: TerminalOverlayPlacement,
        outerInsets: TerminalInsets = .zero,
        contentInsets: TerminalInsets = TerminalInsets(
            vertical: 1,
            horizontal: 2
        ),
        style: TerminalOverlayStyle = .standard
    ) {
        self.placement = placement
        self.outerInsets = outerInsets
        self.contentInsets = contentInsets
        self.style = style
    }

    public func region(
        in container: TerminalRegion
    ) -> TerminalRegion {
        let available = container.inset(
            by: outerInsets
        )

        switch placement {
        case .centered(
            let requestedColumns,
            let requestedRows
        ):
            let columns = min(
                available.columns,
                max(
                    0,
                    requestedColumns
                )
            )
            let rows = min(
                available.rows,
                max(
                    0,
                    requestedRows
                )
            )

            return TerminalRegion(
                top:
                    available.top
                    + max(
                        0,
                        available.rows - rows
                    ) / 2,
                leading:
                    available.leading
                    + max(
                        0,
                        available.columns - columns
                    ) / 2,
                rows: rows,
                columns: columns
            )

        case .trailing(let requestedColumns):
            let columns = min(
                available.columns,
                max(
                    0,
                    requestedColumns
                )
            )

            return TerminalRegion(
                top: available.top,
                leading:
                    available.trailing
                    - columns,
                rows: available.rows,
                columns: columns
            )
        }
    }

    public func contentRegion(
        in container: TerminalRegion
    ) -> TerminalRegion {
        let region = region(
            in: container
        )

        guard region.rows >= 2,
              region.columns >= 2 else {
            return TerminalRegion(
                top: region.top,
                leading: region.leading,
                rows: 0,
                columns: 0
            )
        }

        return region
            .inset(
                by: TerminalInsets(
                    top: 1,
                    leading: 1,
                    bottom: 1,
                    trailing: 1
                )
            )
            .inset(
                by: contentInsets
            )
    }

    @discardableResult
    public func render(
        into frame: inout TerminalFrame,
        in container: TerminalRegion,
        title: String? = nil,
        zIndex: TerminalZIndex = .base
    ) -> TerminalRegion {
        let region = region(
            in: container
        )

        guard !region.isEmpty else {
            return region
        }

        frame.write(
            Array(
                repeating: "",
                count: region.rows
            ),
            in: region,
            zIndex: zIndex
        )

        guard region.rows >= 2,
              region.columns >= 2 else {
            return contentRegion(
                in: container
            )
        }

        let innerColumns = max(
            0,
            region.columns - 2
        )
        let top = topBorder(
            title: title,
            innerColumns: innerColumns
        )
        let middle = style.border.apply(
            "│"
        )
            + String(
                repeating: " ",
                count: innerColumns
            )
            + style.border.apply(
                "│"
            )
        let bottom = style.border.apply(
            "└"
                + String(
                    repeating: "─",
                    count: innerColumns
                )
                + "┘"
        )

        var lines: [String] = [
            top,
        ]

        if region.rows > 2 {
            lines.append(
                contentsOf: Array(
                    repeating: middle,
                    count: region.rows - 2
                )
            )
        }

        lines.append(
            bottom
        )

        frame.write(
            lines,
            in: region,
            zIndex: zIndex
        )

        return contentRegion(
            in: container
        )
    }

    private func topBorder(
        title: String?,
        innerColumns: Int
    ) -> String {
        guard let title,
              !title.isEmpty,
              innerColumns > 0 else {
            return style.border.apply(
                "┌"
                    + String(
                        repeating: "─",
                        count: innerColumns
                    )
                    + "┐"
            )
        }

        let clippedTitle = TerminalDisplay.clipped(
            " \(title) ",
            columns: innerColumns
        )
        let remaining = max(
            0,
            innerColumns
            - TerminalDisplay.width(
                of: clippedTitle
            )
        )

        return style.border.apply(
            "┌"
        )
            + style.title.apply(
                clippedTitle
            )
            + style.border.apply(
                String(
                    repeating: "─",
                    count: remaining
                )
                + "┐"
            )
    }
}
