import Foundation
import Difference
import Terminal

enum TerminalDifferenceSmoke {
    enum Failure: Error {
        case missingRowStyle
        case incorrectRowCount
        case changedStandardColors
        case changedDefaultStyle
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

        let rendered_default = TerminalDifferenceRenderer.render(
            layout,
            options: .init(base: base)
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
        guard rendered_default == filled else {
            throw Failure.changedDefaultStyle
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
        guard filled[2] == standard[2] else {
            throw Failure.changedEqualRow
        }
        let barOptions = DifferenceRenderOptions(
            showHeader: false,
            showUnchangedLines: true,
            lineComponents: [.bar, .lineNumbers, .marker, .text],
            changeBar: "┃"
        )
        let barPlan = DifferenceRenderPlan.make(layout, options: barOptions)
        let barRendered = TerminalDifferenceRenderer.render(
            layout, options: .init(base: barOptions, style: .filled)
        )
        guard barPlan.lines[0].segments.first?.component == .bar,
              barRendered.contains("┃") else {
            throw Failure.incorrectRowCount
        }
        let finalNewline = TextDiffer.diff(old: "a", new: "a\n")
        let patch = try finalNewline.unified(context: 0)
        guard patch.contains("@@ -1,1 +1,1 @@"),
              patch.contains("\\ No newline at end of file") else {
            throw Failure.incorrectRowCount
        }
        let splitSource = TextDiffer.diff(
            old: "prefix\nlet timeout = 30\nobsolete()\nsuffix\n",
            new: "prefix\nlet timeout = 45\nsuffix\n"
        )
        let splitOptions = DifferenceRenderOptions(
            showHeader: false,
            showUnchangedLines: false,
            contextLineCount: 1,
            collapseSeparator: " ... {count} unchanged lines",
            showHunkHeaders: true
        )
        let split = DifferenceLayout.project(splitSource, mode: .split, options: splitOptions)
        guard split.rows.contains(where: { $0.old?.role == .delete && $0.new?.role == .insert }),
              split.rows.contains(where: { $0.old?.role == .delete && $0.new == nil }),
              split.rows.contains(where: {
                  if case .hunk = $0.kind { return true }
                  return false
              }) else {
            throw Failure.incorrectRowCount
        }
        for columns in [120, 80, 56] {
            let rendered = TerminalDifferenceRenderer.render(
                split, options: .init(base: splitOptions, style: .filled, columns: columns)
            )
            let body = rendered.components(separatedBy: "\n").filter { $0.contains("│") }
            guard !body.isEmpty, body.allSatisfy({ TerminalDisplay.width(of: $0) == columns }) else {
                throw Failure.incorrectRowCount
            }
        }
        let geoOptions = TerminalDifferenceRenderOptions(
            base: splitOptions, style: .filled, width: .fixed(64)
        )
        let geoOutput = TerminalDifferenceRenderer.render(split, options: geoOptions)
        let geoRows = geoOutput.components(separatedBy: "\n").filter { $0.contains("│") }
        guard !geoRows.isEmpty, geoRows.allSatisfy({ TerminalDisplay.width(of: $0) == 64 }) else {
            throw Failure.incorrectRowCount
        }
        let padded = TerminalDifferenceRenderer.render(
            split, options: .init(base: splitOptions, width: .content(padding: 2, limit: 80))
        )
        let paddedRows = padded.components(separatedBy: "\n").filter { $0.contains("│") }
        guard paddedRows.allSatisfy({ TerminalDisplay.width(of: $0) <= 80 }) else {
            throw Failure.incorrectRowCount
        }
        let inlineDifference = TextDiffer.diff(
            old: "let timeout = 30; retries = 2\n",
            new: "let timeout = 45; retries = 4\n"
        )
        let analyzed = inlineDifference.analyze(options: .init(
            pairing: .similarity(minimum: 0.3), inline: .characters
        ))
        let annotated = DifferenceLayout.project(analyzed, mode: .split, options: splitOptions)
        let highlighted = TerminalDifferenceRenderer.render(
            annotated, options: .init(base: splitOptions, style: .filled, width: .fixed(56))
        )
        let highlightRows = highlighted.components(separatedBy: "\n").filter { $0.contains("│") }
        guard !highlightRows.isEmpty,
              highlightRows.allSatisfy({ TerminalDisplay.width(of: $0) == 56 }),
              highlighted.contains("\u{001B}[48;2;") else {
            throw Failure.incorrectRowCount
        }
        let unifiedAnalysis = DifferenceLayout.project(analyzed, mode: .unified, options: splitOptions)
        let unifiedHighlight = TerminalDifferenceRenderer.render(
            unifiedAnalysis, options: .init(base: splitOptions, style: .standard, width: .fixed(56))
        )
        guard unifiedHighlight.contains("\u{001B}[48;2;") else {
            throw Failure.incorrectRowCount
        }
        print("terminal difference preset smoke passed")
    }
}
