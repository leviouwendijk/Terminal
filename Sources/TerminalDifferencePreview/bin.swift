import Difference
import Terminal

@main
struct TerminalDifferencePreview {
    enum Failure: Error {
        case missing_bar
        case missing_context
        case missing_color
        case missing_hunk
        case incorrectRowCount
    }

    static func main() throws {
        var old = (1...72).map { "let value_\($0) = \($0)" }
        old[10] = "let timeout = 30"
        old[13] = "obsolete()"
        old[50] = "let retries = 2"

        var new = old
        new[10] = "let timeout = 45"
        new.remove(at: 13)
        new[49] = "let retries = 4"
        new.insert("log(\"retry scheduled\")", at: 50)

        let difference = TextDiffer.diff(
            old: old.joined(separator: "\n") + "\n",
            new: new.joined(separator: "\n") + "\n",
            oldName: "a/Sources/Session.swift",
            newName: "b/Sources/Session.swift"
        )

        let bars = DifferenceRenderOptions(
            showHeader: true,
            showUnchangedLines: false,
            contextLineCount: 2,
            collapseSeparator: " ... {count} unchanged lines",
            showEndOfFile: true,
            lineComponents: [.bar, .lineNumbers, .border, .marker, .text],
            lineNumberFormat: .columns,
            changeBar: "┃"
        )

        let layout = DifferenceLayout.make(difference, options: bars)
        let standard = TerminalDifferenceRenderer.render(
            layout, options: .init(base: bars, style: .standard)
        )
        let filled = TerminalDifferenceRenderer.render(
            layout, options: .init(base: bars, style: .filled)
        )
        let fitted = TerminalDifferenceRenderer.render(
            layout, options: .init(base: bars, style: .filled, columns: 56)
        )
        let patch = try difference.unified(context: 2)

        guard standard.contains("┃") else { throw Failure.missing_bar }
        guard layout.lines.contains(where: { ($0.collapsedCount ?? 0) > 0 }) else {
            throw Failure.missing_context
        }
        guard filled.contains("\u{001B}[") else { throw Failure.missing_color }
        guard patch.contains("@@ -") else { throw Failure.missing_hunk }

        show("01 DEFAULT FILLED / UNIFIED", TerminalDifferenceRenderer.render(difference))
        show("02 STANDARD / BARS / TWO-COLUMN GUTTER", standard)
        show("03 FILLED / BARS / TWO-COLUMN GUTTER", filled)
        show("04 FILLED / 56-COLUMN OUTPUT", fitted)
        show("05 TRUE UNIFIED PATCH (NO ANSI)", patch)
        let split = DifferenceRenderOptions(
            showHeader: true,
            showUnchangedLines: false,
            contextLineCount: 2,
            collapseSeparator: " ... {count} unchanged lines",
            showEndOfFile: false,
            showHunkHeaders: true,
            lineComponents: [.bar, .lineNumbers, .border, .marker, .text],
            lineNumberFormat: .columns
        )
        let projected = DifferenceLayout.project(difference, mode: .split, options: split)
        guard projected.rows.contains(where: {
            if case .hunk = $0.kind { return true }
            return false
        }), projected.rows.contains(where: { $0.old?.role == .delete && $0.new?.role == .insert }) else {
            throw Failure.incorrectRowCount
        }
        for width in [120, 80, 56] {
            let output = TerminalDifferenceRenderer.render(
                projected,
                options: .init(base: split, style: .filled, columns: width)
            )
            let body = output.components(separatedBy: "\n").filter { $0.contains("│") }
            guard !body.isEmpty, body.allSatisfy({ TerminalDisplay.width(of: $0) == width }) else {
                throw Failure.incorrectRowCount
            }
            show("SPLIT / \(width) COLUMNS", output)
        }
        let longOld = "func run() {\n" +
            "\tlet request = service.configure(retries: 2, timeout: 30, description: \"日本語 漢字 extended source content preserving indentation and long expressions\")\n" +
            "    obsolete()\n" +
            "}\n"
        let longNew = "func run() {\n" +
            "\tlet request = service.configure(retries: 2, timeout: 45, description: \"日本語 漢字 extended source content preserving indentation and long expressions\")\n" +
            "    log(\"updated\")\n" +
            "}\n"
        let longDifference = TextDiffer.diff(old: longOld, new: longNew)
        let longProjection = DifferenceLayout.project(longDifference, mode: .split, options: split)
        show("SPLIT / 56 COLUMNS / WRAP + UNICODE + TABS",
             TerminalDifferenceRenderer.render(longProjection, options: .init(
                 base: split, style: .standard, columns: 56
             )))
        show("SPLIT / CONTENT WIDTH / MAX 100", TerminalDifferenceRenderer.render(
            longProjection, options: .init(base: split, style: .filled,
                                           width: .content(padding: 2, limit: 100))
        ))
        show("SPLIT / TERMINAL WIDTH", TerminalDifferenceRenderer.render(
            projected, options: .init(base: split, style: .standard, width: .terminal)
        ))
        let annotatedDifference = longDifference.analyze(options: .init(
            pairing: .similarity(minimum: 0.3), inline: .characters
        ))
        let annotatedSplit = DifferenceLayout.project(
            annotatedDifference, mode: .split, options: split
        )
        let annotatedUnified = DifferenceLayout.project(
            annotatedDifference, mode: .unified, options: split
        )
        show("INLINE / SPLIT / CONTENT MAX 100", TerminalDifferenceRenderer.render(
            annotatedSplit, options: .init(base: split, style: .filled,
                                           width: .content(padding: 2, limit: 100))
        ))
        show("INLINE / SPLIT / 56 COLUMNS", TerminalDifferenceRenderer.render(
            annotatedSplit, options: .init(base: split, style: .filled, width: .fixed(56))
        ))
        show("INLINE / UNIFIED / 80 COLUMNS", TerminalDifferenceRenderer.render(
            annotatedUnified, options: .init(base: split, style: .standard, width: .fixed(80))
        ))
        let edgeBefore = "func process() {\n" +
            "\tlet label = \"日本語 漢字 🇯🇵 e\u{301} some extended long content for terminal wrapping\"; timeout = 30\n" +
            "}\n"
        let edgeAfter = "func process() {\n" +
            "\tlet label = \"日本語 漢字 🇯🇵 e\u{301} some extended long content for terminal wrapping\"; timeout = 45\n" +
            "    log(\"more content on the right\")\n" +
            "}\n"
        let edge = TextDiffer.diff(old: edgeBefore, new: edgeAfter)
        let edgeAnalysis = edge.analyze(options: .init(
            pairing: .similarity(minimum: 0.3), inline: .characters
        ))
        let edgeProjection = DifferenceLayout.project(edgeAnalysis, mode: .split, options: split)
        show("CELL GRID / SPLIT / 56 COLUMNS / WIDE GLYPHS + WRAP", TerminalDifferenceRenderer.render(
            edgeProjection, options: .init(base: split, style: .filled, width: .fixed(56))
        ))
        let terminalColumns = Terminal.size(for: .standardOutput).columns
        let terminalPreview = TerminalDifferenceRenderer.render(
            edgeProjection,
            options: .init(
                base: split,
                style: .filled,
                width: .terminal
            )
        )
        show(
            "CELL GRID / SPLIT / FILLED / TERMINAL WIDTH (\(terminalColumns) COLUMNS)",
            terminalPreview
        )

        let widthSample = "日本語 漢字 🇯🇵 e\u{301}"
        let measured = TerminalDisplay.width(of: widthSample)
        guard measured == 16 else {
            throw Failure.incorrectRowCount
        }
        show("UNICODE WIDTH / EXPECTED 16 / ACTUAL \(measured)", widthSample)
        show("TOKENS / SPLIT / 56 COLUMNS / FILLED", TerminalDifferenceRenderer.render(
            edgeProjection, options: .init(base: split, style: .filled,
                                           width: .fixed(56), wrap: .tokens)
        ))
        show("WORDS / SPLIT / 56 COLUMNS / FILLED", TerminalDifferenceRenderer.render(
            edgeProjection, options: .init(base: split, style: .filled,
                                           width: .fixed(56), wrap: .words)
        ))
        show("TOKENS / SPLIT / TERMINAL WIDTH / FILLED", TerminalDifferenceRenderer.render(
            edgeProjection, options: .init(base: split, style: .filled,
                                           width: .terminal, wrap: .tokens)
        ))
        print("\nDIFF PREVIEW PASSED")
    }

    private static func show(_ title: String, _ output: String) {
        print("\n========== \(title) ==========")
        print(output)
    }
}
