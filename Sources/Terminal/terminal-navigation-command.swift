/// A view-independent navigation request: what a key or counted key sequence asks
/// a list, tree or document to do. Each view decides its own unit (item, row,
/// message). Counted movement clamps at the ends; it never wraps.
public enum TerminalNavigationCommand:
    Sendable,
    Hashable
{
    /// Signed steps; negative moves up.
    case vertical(Int)
    /// Signed steps; negative moves left.
    case horizontal(Int)
    case first
    case last
    /// A zero-based position, clamped to the content.
    case position(Int)
    /// Signed pages; negative moves up.
    case page(Int)
    /// Signed half pages; negative moves up.
    case halfPage(Int)
}

public extension TerminalNavigationCommand {
    /// The single-key defaults for views without a count grammar.
    init?(
        key: TerminalKey
    ) {
        switch key {
        case .home:
            self = .first

        case .end:
            self = .last

        case .pageUp:
            self = .page(-1)

        case .pageDown:
            self = .page(1)

        default:
            if let action = key.navigationAction(
                on: .vertical
            ) {
                self = .vertical(
                    action == .next ? 1 : -1
                )
            } else if let action = key.navigationAction(
                on: .horizontal
            ) {
                self = .horizontal(
                    action == .next ? 1 : -1
                )
            } else {
                return nil
            }
        }
    }

    /// The signed step count for vertical movement, with pages expressed in
    /// `pageRows`. `nil` for absolute and horizontal commands.
    func verticalSteps(
        pageRows: Int
    ) -> Int? {
        let pageRows = max(
            1,
            pageRows
        )

        switch self {
        case .vertical(let steps):
            return steps

        case .page(let pages):
            return Self.saturatingProduct(
                pages,
                max(1, pageRows - 1)
            )

        case .halfPage(let pages):
            return Self.saturatingProduct(
                pages,
                max(1, pageRows / 2)
            )

        case .horizontal,
             .first,
             .last,
             .position:
            return nil
        }
    }

    /// `steps` limited to `limit` in either direction, so callers can add it to
    /// an index or offset without overflowing.
    static func bounded(
        _ steps: Int,
        to limit: Int
    ) -> Int {
        let limit = max(
            0,
            limit
        )

        return min(
            limit,
            max(
                -limit,
                steps
            )
        )
    }

    private static func saturatingProduct(
        _ lhs: Int,
        _ rhs: Int
    ) -> Int {
        let (
            product,
            overflow
        ) = lhs.multipliedReportingOverflow(
            by: rhs
        )

        guard overflow else {
            return product
        }

        return (lhs < 0) == (rhs < 0)
            ? Int.max
            : Int.min
    }
}

extension TerminalScrollableDocument {
    /// Applies vertical navigation in rows. Horizontal commands are not handled.
    @discardableResult
    public mutating func apply(
        _ command: TerminalNavigationCommand
    ) -> Bool {
        switch command {
        case .first:
            let changed = viewport.offset != 0
            moveToStart()
            return changed

        case .last:
            let changed = viewport.offset != viewport.maximumOffset
            moveToEnd()
            return changed

        case .position(let row):
            let previousOffset = viewport.offset
            moveToStart()
            let target = min(
                max(0, row),
                viewport.maximumOffset
            )
            if target > 0 {
                scrollDown(
                    by: target
                )
            }
            return viewport.offset != previousOffset

        case .horizontal:
            return false

        case .vertical,
             .page,
             .halfPage:
            guard let steps = command.verticalSteps(
                pageRows: viewport.visibleRows
            ) else {
                return false
            }

            let bounded = TerminalNavigationCommand.bounded(
                steps,
                to: lines.count
            )

            if bounded < 0 {
                return scrollUp(
                    by: -bounded
                )
            }

            if bounded > 0 {
                return scrollDown(
                    by: bounded
                )
            }

            return false
        }
    }
}
