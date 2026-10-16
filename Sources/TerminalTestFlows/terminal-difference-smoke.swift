import Foundation
import Difference
import Terminal

enum TerminalDifferenceSmoke {
    enum Failure: Error {
        case missingRowStyle
        case incorrectRowCount
        case changedStandardColors
        case incorrectDeletionFill
        case incorrectInsertionFill
        case changedEqualRow
        case incorrectPaddedRow
        case incorrectClippedRow
        case changedStandardWithColumns
    }

    static func run() throws {
        let layout = DifferenceLayout(
            lines: [
                .init(role: .delete, text: "old", coordinate: .init(old: 1)),
                .init(role: .insert, text: "new", coordinate: .init(new: 1)),
                .init(role: .equal, text: "context", coordinate: .init(old: 2, new: 2)),
            ]
        )
        let base = DifferenceRenderOptions(
            showHeader: false,
            showUnchangedLines: true
        )
        let plan = DifferenceRenderPlan.make(layout, options: base)
        let standard = TerminalDifferenceRenderer.render(
            layout,
            options: .init(base: base, style: .standard)
        ).components(separatedBy: "\n")
        let filled = TerminalDifferenceRenderer.render(
            layout,
            options: .init(base: base, style: .filled)
        ).components(separatedBy: "\n")

        guard plan.lines.count == 3,
              standard.count == 3,
              filled.count == 3 else {
            throw Failure.incorrectRowCount
        }
        guard standard[0].contains("\u{001B}[31m"),
              standard[1].contains("\u{001B}[32m"),
              !standard[0].contains("\u{001B}[48;2;"),
              !standard[1].contains("\u{001B}[48;2;") else {
            throw Failure.changedStandardColors
        }
        guard let deletion = TerminalDifferenceStyle.filled.deleteRow,
              let insertion = TerminalDifferenceStyle.filled.insertRow else {
            throw Failure.missingRowStyle
        }
        func rowText(_ index: Int) -> String {
            let row = plan.lines[index]
            let spacing = String(repeating: " ", count: row.componentSpacing)
            return row.segments.map(\.text).joined(separator: spacing)
        }
        guard filled[0] == deletion.apply(rowText(0)) else {
            throw Failure.incorrectDeletionFill
        }
        guard filled[1] == insertion.apply(rowText(1)) else {
            throw Failure.incorrectInsertionFill
        }
        guard filled[2] == standard[2] else {
            throw Failure.changedEqualRow
        }
        let columns = 36
        let sizedFilled = TerminalDifferenceRenderer.render(
            layout,
            options: .init(base: base, style: .filled, columns: columns)
        ).components(separatedBy: "\n")
        let sizedStandard = TerminalDifferenceRenderer.render(
            layout,
            options: .init(base: base, style: .standard, columns: columns)
        ).components(separatedBy: "\n")

        guard sizedFilled.count == 3,
              sizedFilled[0] == deletion.apply(
                TerminalDisplay.fitted(rowText(0), columns: columns)
              ),
              sizedFilled[1] == insertion.apply(
                TerminalDisplay.fitted(rowText(1), columns: columns)
              ),
              sizedFilled[2] == standard[2],
              TerminalDisplay.width(
                of: TerminalDisplay.fitted(rowText(0), columns: columns)
              ) == columns else {
            throw Failure.incorrectPaddedRow
        }
        guard sizedStandard == standard else {
            throw Failure.changedStandardWithColumns
        }

        let narrow = TerminalDifferenceRenderer.render(
            layout,
            options: .init(base: base, style: .filled, columns: 5)
        ).components(separatedBy: "\n")
        guard narrow.count == 3,
              narrow[0] == deletion.apply(
                TerminalDisplay.fitted(rowText(0), columns: 5)
              ) else {
            throw Failure.incorrectClippedRow
        }
        print("terminal difference preset smoke passed")
    }
}
