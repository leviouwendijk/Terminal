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
        // Token wrapping must preserve every source grapheme and its inline
        // assignment across ANSI-serialized physical rows, not merely widths.
        // The bold SGR code is emitted only by the inline styles in .filled.
        func decodedStyle(_ pane: Substring) -> (plain: String, inline: String) {
            var plain = ""
            var inline = ""
            var isInline = false
            var cursor = pane.startIndex

            while cursor < pane.endIndex {
                if pane[cursor] == "\u{001B}" {
                    let next = pane.index(after: cursor)
                    if next < pane.endIndex, pane[next] == "[",
                       let end = pane[next...].firstIndex(of: "m") {
                        let sequence = pane[cursor...end]
                        if sequence == "\u{001B}[1m" {
                            isInline = true
                        } else if sequence == "\u{001B}[0m" {
                            isInline = false
                        }
                        cursor = pane.index(after: end)
                        continue
                    }
                }
                let character = pane[cursor]
                plain.append(character)
                if isInline {
                    inline.append(character)
                }
                cursor = pane.index(after: cursor)
            }
            return (plain, inline)
        }

        func inlineSides(_ rendered: String) -> (
            old: String, new: String, oldPlain: String, newPlain: String,
            oldRows: Int, newRows: Int, physicalRows: Int
        ) {
            var old = ""
            var new = ""
            var oldPlain = ""
            var newPlain = ""
            var oldRows = 0
            var newRows = 0
            var physicalRows = 0
            for line in rendered.components(separatedBy: "\n") {
                guard let divider = line.range(of: "│") else { continue }
                physicalRows += 1
                let left = decodedStyle(line[..<divider.lowerBound])
                let right = decodedStyle(line[divider.upperBound...])
                old += left.inline
                new += right.inline
                oldPlain += left.plain
                newPlain += right.plain
                if !left.inline.isEmpty { oldRows += 1 }
                if !right.inline.isEmpty { newRows += 1 }
            }
            return (old, new, oldPlain, newPlain, oldRows, newRows, physicalRows)
        }

        let oldSuffix = String(repeating: "a", count: 70)
            + "  日本語e\u{301}  "
        let newSuffix = String(repeating: "B", count: 74)
            + "漢字東京BBBB"
        let completeDifference = TextDiffer.diff(
            old: "Q" + oldSuffix + "\n",
            new: "Q" + newSuffix + "\n"
        )
        let completeAnalysis = completeDifference.analyze(options: .init(
            pairing: .similarity(minimum: 0.0), inline: .characters
        ))
        let completeProjection = DifferenceLayout.project(
            completeAnalysis, mode: .split, options: splitOptions
        )
        guard completeProjection.rows.contains(where: {
            !($0.old?.spans.isEmpty ?? true) && !($0.new?.spans.isEmpty ?? true)
        }) else {
            throw Failure.incorrectRowCount
        }

        for columns in [48, 56, 80] {
            let output = TerminalDifferenceRenderer.render(
                completeProjection,
                options: .init(
                    base: splitOptions,
                    style: .filled,
                    width: .fixed(columns),
                    wrap: .tokens
                )
            )
            let decoded = inlineSides(output)
            let rows = output.components(separatedBy: "\n")
                .filter { $0.contains("│") }
            // Every changed character, including source spaces, CJK and
            // composed graphemes, must survive wrapping in the right order.
            // The sole unchanged anchor Q must appear once in each pane.
            guard decoded.old.utf8.elementsEqual(oldSuffix.utf8),
                  decoded.new.utf8.elementsEqual(newSuffix.utf8),
                  decoded.oldPlain.filter({ $0 == "Q" }).count == 1,
                  decoded.newPlain.filter({ $0 == "Q" }).count == 1,
                  decoded.oldRows > 1,
                  decoded.newRows > 1,
                  rows.count == decoded.physicalRows,
                  rows.allSatisfy({ TerminalDisplay.width(of: $0) == columns }) else {
                throw Failure.incorrectRowCount
            }
        }

        // A selective inline replacement must not color surrounding text,
        // even when the source line wraps into many physical rows.
        let selective = inlineSides(tokenWrapped)
        guard selective.old.utf8.elementsEqual("30".utf8),
              selective.new.utf8.elementsEqual("45".utf8),
              selective.physicalRows > 2 else {
            throw Failure.incorrectRowCount
        }
        // Prefer source-preserving casing boundaries over mid-identifier splits.
        // Lexical breaks still take precedence; Character breaks remain fallback.
        let identifierOld = "HTTPServerConfigurationManagerHandlerLoopA"
        let identifierNew = "HTTPServerConfigurationManagerHandlerLoopB"
        let identifierDifference = TextDiffer.diff(
            old: identifierOld + "\n", new: identifierNew + "\n"
        )
        let identifierAnalysis = identifierDifference.analyze(options: .init(
            pairing: .similarity(minimum: 0.3), inline: .characters
        ))
        let identifierProjection = DifferenceLayout.project(
            identifierAnalysis, mode: .split, options: splitOptions
        )
        let identifierTokens = TerminalDifferenceRenderer.render(
            identifierProjection, options: .init(
                base: splitOptions, style: .filled, width: .fixed(48), wrap: .tokens
            )
        )
        let identifierWords = TerminalDifferenceRenderer.render(
            identifierProjection, options: .init(
                base: splitOptions, style: .filled, width: .fixed(48), wrap: .words
            )
        )
        func firstLeftContent(_ output: String) -> String? {
            guard let row = output.components(separatedBy: "\n").first(where: { $0.contains("│") }),
                  let divider = row.range(of: "│") else { return nil }
            let pane = decodedStyle(row[..<divider.lowerBound]).plain
            // The one-column bar and fixed six-column number/marker prefix.
            guard pane.count >= 7 else { return nil }
            return String(pane.dropFirst(7)).trimmingCharacters(in: .whitespaces)
        }
        guard firstLeftContent(identifierTokens) == "HTTPServer",
              firstLeftContent(identifierWords) == "HTTPServerConf",
              identifierTokens.components(separatedBy: "\n")
                .filter({ $0.contains("│") })
                .allSatisfy({ TerminalDisplay.width(of: $0) == 48 }),
              identifierWords.components(separatedBy: "\n")
                .filter({ $0.contains("│") })
                .allSatisfy({ TerminalDisplay.width(of: $0) == 48 }) else {
            throw Failure.incorrectRowCount
        }
        // Raw text uses review by default, including bounded intraline analysis.
        // Prebuilt layouts remain explicitly legacy unless the caller chooses otherwise.
        let presetDiff = TextDiffer.diff(
            old: "let HTTPServerConfiguration = 30\n",
            new: "let HTTPServerConfiguration = 45\n"
        )
        var reviewPreset = TerminalDifferenceRenderOptions.review
        reviewPreset.width = .fixed(90)
        let reviewOutput = TerminalDifferenceRenderer.render(presetDiff, options: reviewPreset)
        let analysisOutput = TerminalDifferenceRenderer.render(
            presetDiff.analyze(), options: reviewPreset
        )
        let defaultOutput = TerminalDifferenceRenderer.render(presetDiff)
        let compactOutput = TerminalDifferenceRenderer.render(
            presetDiff, options: .compact
        )
        let plainOutput = TerminalDifferenceRenderer.render(presetDiff, options: .plain)
        let legacyOutput = TerminalDifferenceRenderer.render(presetDiff, options: .legacy)
        let originalLayout = DifferenceLayout.make(presetDiff, options: .unified)
        let originalOutput = TerminalDifferenceRenderer.render(
            originalLayout, options: .legacy
        )
        var narrowPreset = TerminalDifferenceRenderOptions.review
        narrowPreset.width = .fixed(56)
        let narrowOutput = TerminalDifferenceRenderer.render(
            presetDiff, options: narrowPreset
        )
        guard TerminalDifferenceRenderOptions.review.wrap == .tokens,
              TerminalDifferenceRenderOptions.review.style == .filled,
              reviewOutput == analysisOutput,
              reviewOutput.contains("│"),
              reviewOutput.contains("\u{001B}[1m"),
              reviewOutput.contains("@@ -"),
              !defaultOutput.isEmpty,
              !compactOutput.contains("│"),
              !plainOutput.contains("\u{001B}"),
              !plainOutput.contains("│"),
              !narrowOutput.contains("│"),
              legacyOutput == originalOutput else {
            throw Failure.incorrectRowCount
        }
        // A subprocess with stdout connected to a pipe must print uncolored
        // unified review content, even though render() remains explicitly styled.
        let pipeProbe = Process()
        pipeProbe.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        pipeProbe.arguments = ["diff-pipe-probe"]
        let outputPipe = Pipe()
        pipeProbe.standardOutput = outputPipe
        try pipeProbe.run()
        let bytes = outputPipe.fileHandleForReading.readDataToEndOfFile()
        pipeProbe.waitUntilExit()
        guard pipeProbe.terminationStatus == 0,
              let printed = String(data: bytes, encoding: .utf8),
              !printed.contains("\u{001B}"),
              !printed.contains("│"),
              printed.contains("let timeout = 30"),
              printed.contains("let timeout = 45"),
              printed.contains("@@ -") else {
            throw Failure.incorrectRowCount
        }
        print("terminal difference preset smoke passed")
    }
}
