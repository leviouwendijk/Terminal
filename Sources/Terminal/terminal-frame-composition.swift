public struct TerminalResolvedFrame:
    Sendable,
    Hashable
{
    public var rows: Int
    public var columns: Int
    public private(set) var spans: [TerminalFrameSpan]
    public var cursor: TerminalFrameCursor?

    private var spansByRow: [[TerminalFrameSpan]]

    public init(
        rows: Int,
        columns: Int,
        spans: [TerminalFrameSpan],
        cursor: TerminalFrameCursor? = nil
    ) {
        let resolvedRows = max(
            0,
            rows
        )
        let resolvedColumns = max(
            0,
            columns
        )
        var spansByRow = Array(
            repeating: [TerminalFrameSpan](),
            count: resolvedRows
        )

        for span in spans where
            span.row >= 0
                && span.row < resolvedRows
        {
            spansByRow[span.row].append(
                span
            )
        }

        self.rows = resolvedRows
        self.columns = resolvedColumns
        self.spans = spans
        self.cursor = cursor
        self.spansByRow = spansByRow
    }

    public func spans(
        inRow row: Int
    ) -> [TerminalFrameSpan] {
        guard row >= 0,
              row < spansByRow.count else {
            return []
        }

        return spansByRow[row]
    }
}

private struct TerminalFrameOrderedSpan {
    var order: Int
    var span: TerminalFrameSpan
}

public extension TerminalFrame {
    func resolved() -> TerminalResolvedFrame {
        var spansByRow = Array(
            repeating: [TerminalFrameOrderedSpan](),
            count: rows
        )

        for entry in spans.enumerated() {
            let span = entry.element

            guard span.row >= 0,
                  span.row < rows else {
                continue
            }

            spansByRow[span.row].append(
                TerminalFrameOrderedSpan(
                    order: entry.offset,
                    span: span
                )
            )
        }

        return TerminalResolvedFrame(
            rows: rows,
            columns: columns,
            spans: spansByRow.flatMap {
                resolve(
                    $0
                )
            },
            cursor: cursor
        )
    }

    func resolvedSpans(
        inRow row: Int
    ) -> [TerminalFrameSpan] {
        guard row >= 0,
              row < rows else {
            return []
        }

        let ordered = spans.enumerated().compactMap {
            entry -> TerminalFrameOrderedSpan? in

            guard entry.element.row == row else {
                return nil
            }

            return TerminalFrameOrderedSpan(
                order: entry.offset,
                span: entry.element
            )
        }

        return resolve(
            ordered
        )
    }

    private func resolve(
        _ entries: [TerminalFrameOrderedSpan]
    ) -> [TerminalFrameSpan] {
        let ordered = entries.sorted {
            lhs,
            rhs in

            if lhs.span.zIndex != rhs.span.zIndex {
                return lhs.span.zIndex < rhs.span.zIndex
            }

            return lhs.order < rhs.order
        }
        var resolved: [TerminalFrameSpan] = []

        for entry in ordered {
            guard let incoming = clippedToFrame(
                entry.span
            ) else {
                continue
            }

            let covered = incoming.leading..<(incoming.leading + incoming.columns)

            resolved = resolved.flatMap {
                subtract(
                    covered,
                    from: $0
                )
            }
            resolved.append(
                incoming
            )
        }

        return resolved
            .sorted {
                lhs,
                rhs in

                lhs.leading < rhs.leading
            }
            .map {
                TerminalFrameSpan(
                    row: $0.row,
                    leading: $0.leading,
                    columns: $0.columns,
                    content: $0.content
                )
            }
    }
}

private extension TerminalFrame {
    func clippedToFrame(
        _ span: TerminalFrameSpan
    ) -> TerminalFrameSpan? {
        guard span.columns > 0,
              span.leading < columns else {
            return nil
        }

        let visibleColumns = min(
            span.columns,
            columns - span.leading
        )

        guard visibleColumns > 0 else {
            return nil
        }

        let content = TerminalDisplay.fitted(
            span.content,
            columns: span.columns
        )

        return TerminalFrameSpan(
            row: span.row,
            leading: span.leading,
            columns: visibleColumns,
            content: TerminalDisplay.slice(
                content,
                columns: 0..<visibleColumns
            ),
            zIndex: span.zIndex
        )
    }

    func subtract(
        _ covered: Range<Int>,
        from span: TerminalFrameSpan
    ) -> [TerminalFrameSpan] {
        let spanRange = span.leading..<(span.leading + span.columns)

        guard spanRange.overlaps(
            covered
        ) else {
            return [
                span,
            ]
        }

        let overlapStart = max(
            spanRange.lowerBound,
            covered.lowerBound
        )
        let overlapEnd = min(
            spanRange.upperBound,
            covered.upperBound
        )
        var fragments: [TerminalFrameSpan] = []

        if overlapStart > spanRange.lowerBound {
            let fragmentColumns =
                overlapStart
                - spanRange.lowerBound

            fragments.append(
                TerminalFrameSpan(
                    row: span.row,
                    leading: span.leading,
                    columns: fragmentColumns,
                    content: TerminalDisplay.slice(
                        span.content,
                        columns: 0..<fragmentColumns
                    ),
                    zIndex: span.zIndex
                )
            )
        }

        if overlapEnd < spanRange.upperBound {
            let offset =
                overlapEnd
                - spanRange.lowerBound
            let fragmentColumns =
                spanRange.upperBound
                - overlapEnd

            fragments.append(
                TerminalFrameSpan(
                    row: span.row,
                    leading: overlapEnd,
                    columns: fragmentColumns,
                    content: TerminalDisplay.slice(
                        span.content,
                        columns: offset..<(offset + fragmentColumns)
                    ),
                    zIndex: span.zIndex
                )
            )
        }

        return fragments
    }
}
