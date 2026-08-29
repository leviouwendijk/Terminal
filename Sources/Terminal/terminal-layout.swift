public enum TerminalLength:
    Sendable,
    Codable,
    Hashable
{
    case fixed(Int)
    case flex(Int)
}

public enum TerminalLayout {
    public static func vertical(
        in region: TerminalRegion,
        _ lengths: [TerminalLength],
        spacing: Int = 0
    ) -> [TerminalRegion] {
        let sizes = resolve(
            total: region.rows,
            lengths: lengths,
            spacing: spacing
        )
        let spacing = max(
            0,
            spacing
        )

        var top = region.top

        return sizes.enumerated().map {
            index,
            rows in

            defer {
                top += rows

                if index < sizes.count - 1 {
                    top += spacing
                }
            }

            return TerminalRegion(
                top: top,
                leading: region.leading,
                rows: rows,
                columns: region.columns
            )
        }
    }

    public static func horizontal(
        in region: TerminalRegion,
        _ lengths: [TerminalLength],
        spacing: Int = 0
    ) -> [TerminalRegion] {
        let sizes = resolve(
            total: region.columns,
            lengths: lengths,
            spacing: spacing
        )
        let spacing = max(
            0,
            spacing
        )

        var leading = region.leading

        return sizes.enumerated().map {
            index,
            columns in

            defer {
                leading += columns

                if index < sizes.count - 1 {
                    leading += spacing
                }
            }

            return TerminalRegion(
                top: region.top,
                leading: leading,
                rows: region.rows,
                columns: columns
            )
        }
    }

    private static func resolve(
        total: Int,
        lengths: [TerminalLength],
        spacing: Int
    ) -> [Int] {
        guard !lengths.isEmpty else {
            return []
        }

        let spacingTotal = max(
            0,
            spacing
        ) * max(
            0,
            lengths.count - 1
        )
        let available = max(
            0,
            total - spacingTotal
        )

        let fixedTotal = lengths.reduce(
            0
        ) {
            total,
            length in

            switch length {
            case .fixed(let amount):
                return total + max(
                    0,
                    amount
                )

            case .flex:
                return total
            }
        }

        if fixedTotal > available {
            var remaining = available

            return lengths.map {
                length in

                switch length {
                case .fixed(let amount):
                    let resolved = min(
                        remaining,
                        max(
                            0,
                            amount
                        )
                    )

                    remaining -= resolved
                    return resolved

                case .flex:
                    return 0
                }
            }
        }

        let flexibleSpace = available - fixedTotal
        let totalWeight = lengths.reduce(
            0
        ) {
            total,
            length in

            switch length {
            case .fixed:
                return total

            case .flex(let weight):
                return total + max(
                    1,
                    weight
                )
            }
        }

        guard totalWeight > 0 else {
            return lengths.map {
                length in

                switch length {
                case .fixed(let amount):
                    return max(
                        0,
                        amount
                    )

                case .flex:
                    return 0
                }
            }
        }

        var remainingSpace = flexibleSpace
        var remainingWeight = totalWeight

        return lengths.map {
            length in

            switch length {
            case .fixed(let amount):
                return max(
                    0,
                    amount
                )

            case .flex(let weight):
                let weight = max(
                    1,
                    weight
                )

                let resolved: Int

                if remainingWeight == weight {
                    resolved = remainingSpace
                } else {
                    resolved =
                        remainingSpace
                        * weight
                        / remainingWeight
                }

                remainingSpace -= resolved
                remainingWeight -= weight

                return resolved
            }
        }
    }
}
