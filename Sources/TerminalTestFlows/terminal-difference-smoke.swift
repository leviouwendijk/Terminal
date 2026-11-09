import Foundation
import Difference
import Terminal
import Tokens

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
        let edgeOld = "func process() {\n" +
            "\tlet request = network.call(timeout: 30, label: \"日本語 漢字 🇯🇵 e\u{301} extended request with many arguments and visible wrapping\")\n" +
            "}\n"
        let edgeNew = "func process() {\n" +
            "\tlet request = network.call(timeout: 45, label: \"日本語 漢字 🇯🇵 e\u{301} extended request with many arguments and visible wrapping\")\n" +
            "    log(\"updated\")\n" +
            "}\n"
        let edgeDiff = TextDiffer.diff(old: edgeOld, new: edgeNew)
        let edgeAnalysis = edgeDiff.analyze(options: .init(
            pairing: .similarity(minimum: 0.3), inline: .characters
        ))
        let edgeSplit = DifferenceLayout.project(edgeAnalysis, mode: .split, options: splitOptions)
        let edgeOutput = TerminalDifferenceRenderer.render(edgeSplit, options: .init(
            base: splitOptions, style: .filled, width: .fixed(56)
        ))
        let physical = edgeOutput.components(separatedBy: "\n").filter { $0.contains("│") }
        let dividerColumns = physical.compactMap { line -> Int? in
            guard let divider = line.range(of: "│") else { return nil }
            return TerminalDisplay.width(of: String(line[..<divider.lowerBound]))
        }
        guard physical.count >= 4,
              dividerColumns.count == physical.count,
              Set(dividerColumns).count == 1,
              physical.allSatisfy({ TerminalDisplay.width(of: $0) == 56 }),
              edgeOutput.contains("\u{001B}[48;2;") else {
            throw Failure.incorrectRowCount
        }
        // These expected widths are independent of TerminalDisplay's
        // implementation, preventing its own measurements from masking errors.
        let widthFixtures: [(String, Int)] = [
            ("日本語", 6),
            ("漢字", 4),
            ("日本語 漢字", 11),
            ("🇯🇵", 2),
            ("e\u{301}", 1),
            ("日本語 漢字 🇯🇵 e\u{301}", 16)
        ]
        guard widthFixtures.allSatisfy({ sample, expected in
            TerminalDisplay.width(of: sample) == expected
        }) else {
            throw Failure.incorrectRowCount
        }

        // Verify the corrected measurement through the rendered pane boundary.
        let correctedPhysical = edgeOutput.components(separatedBy: "\n")
            .filter { $0.contains("│") }
        guard correctedPhysical.allSatisfy({ line in
            guard let divider = line.range(of: "│") else { return false }
            let left = String(line[..<divider.lowerBound])
            let right = String(line[divider.upperBound...])
            return TerminalDisplay.width(of: left) == dividerColumns[0]
                && TerminalDisplay.width(of: line) == 56
                && !right.isEmpty
        }) else {
            throw Failure.incorrectRowCount
        }
        // EOF must retain the same border column as regular source rows.
        let eofLayout = DifferenceLayout(lines: [
            .init(role: .equal, text: "context", coordinate: .init(old: 12, new: 12)),
            .init(role: .delete, text: "removed", coordinate: .init(old: 13)),
            .init(role: .endOfFile, text: "EOF")
        ])

        func borderColumn(_ line: DifferenceRenderPlan.Line) -> Int? {
            var column = 0
            for (index, segment) in line.segments.enumerated() {
                if index > 0 {
                    column += line.componentSpacing
                }
                if segment.component == .border {
                    return column
                }
                column += TerminalDisplay.width(of: segment.text)
            }
            return nil
        }

        let gutterConfigurations: [[DifferenceLineRenderComponent]] = [
            [.lineNumbers, .border, .marker, .text],
            [.bar, .lineNumbers, .border, .marker, .text],
            [.bar, .lineNumbers, .marker, .border, .text]
        ]

        for format in [DifferenceLineNumberFormat.compact, .columns] {
            for components in gutterConfigurations {
                let options = DifferenceRenderOptions(
                    showHeader: false,
                    showUnchangedLines: true,
                    showEndOfFile: true,
                    lineComponents: components,
                    lineNumberFormat: format
                )
                let planned = DifferenceRenderPlan.make(eofLayout, options: options)
                guard planned.lines.count == 3,
                      let eof = planned.lines.last,
                      eof.role == .endOfFile,
                      let target = borderColumn(eof),
                      planned.lines.dropLast().allSatisfy({ borderColumn($0) == target }),
                      eof.segments.contains(where: { $0.component == .bar }) == components.contains(.bar),
                      eof.segments.filter({ $0.component == .bar }).allSatisfy({ $0.text == " " }) else {
                    throw Failure.incorrectRowCount
                }
            }
        }

        let lexicalSource = "HTTPServer42: 日本語 🇯🇵 e\u{301}"
        let boundaries = try TokenBoundaries.lexical(lexicalSource)
        let lexicalBytes = Array(lexicalSource.utf8)
        var previousEnd = 0
        for segment in boundaries {
            let start = segment.utf8.lowerBound.offset
            let end = segment.utf8.upperBound.offset
            guard start == previousEnd,
                  String(decoding: lexicalBytes[start..<end], as: UTF8.self) == segment.rawValue else {
                throw Failure.incorrectRowCount
            }
            _ = try segment.coordinates(in: lexicalSource)
            previousEnd = end
        }
        guard previousEnd == lexicalBytes.count,
              boundaries.map(\.rawValue).joined() == lexicalSource else {
            throw Failure.incorrectRowCount
        }
        let tokenWrapped = TerminalDifferenceRenderer.render(
            edgeSplit, options: .init(
                base: splitOptions, style: .filled, width: .fixed(56), wrap: .tokens
            )
        )
        let wordWrapped = TerminalDifferenceRenderer.render(
            edgeSplit, options: .init(
                base: splitOptions, style: .filled, width: .fixed(56), wrap: .words
            )
        )
        for output in [tokenWrapped, wordWrapped] {
            let rows = output.components(separatedBy: "\n").filter { $0.contains("│") }
            guard !rows.isEmpty, rows.allSatisfy({ TerminalDisplay.width(of: $0) == 56 }),
                  output.contains("\u{001B}[48;2;") else {
                throw Failure.incorrectRowCount
            }
        }
        print("terminal difference preset smoke passed")
    }
}
