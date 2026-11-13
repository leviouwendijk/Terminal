import Foundation
import Darwin
import Terminal
import TerminalGhostty

@main
struct TerminalGhosttyTestFlows {
    static func main() {
        do {
            try run()
            print("PASS t_terminal_ghostty")
        } catch {
            fputs("FAIL t_terminal_ghostty: \(error)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }

    static func run() throws {
        let screen = try GhosttyTerminalScreen(columns: 20, rows: 4)
        screen.feed("First\r\nSecond")
        let initial = try screen.snapshot()
        try expect(initial.contains("First"), "missing first row")
        try expect(initial.contains("Second"), "missing second row")

        screen.feed("\u{001B}[1;1HChanged")
        let changed = try screen.snapshot()
        try expect(changed.contains("Changed"), "cursor update was not applied")
        try expect(!changed.contains("First"), "stale first row")

        let colored = try GhosttyTerminalScreen(columns: 20, rows: 2)
        colored.feed("\u{001B}[32mGreen\u{001B}[0m")
        let plain = try colored.snapshot()
        try expect(plain.contains("Green"), "styled text was lost")
        try expect(!plain.contains("\u{001B}"), "plain snapshot contains escapes")

        do {
            _ = try GhosttyTerminalScreen(columns: 0, rows: 3)
            throw TestFailure.failed("zero-width screen accepted")
        } catch GhosttyTerminalError.invalid_size {
            // Expected.
        }

        try frameRendering()
        try physicalGeometry()
    }

    static func frameRendering() throws {
        for columns in [24, 40, 80] {
            let rows = 5
            let screen = try GhosttyTerminalScreen(
                columns: columns,
                rows: rows
            )
            var renderer = TerminalFrameRenderer()
            let region = TerminalRegion(
                top: 1,
                leading: 2,
                rows: 2,
                columns: columns - 4
            )

            var initial = TerminalFrame(
                rows: rows,
                columns: columns
            )
            initial.write(
                ["baseline-A", "baseline-B"],
                in: region
            )

            let firstSequence = renderer.encode(initial)
            try expect(
                firstSequence.contains("\u{001B}["),
                "initial frame lacks VT commands at width \(columns)"
            )
            screen.feed(firstSequence)

            let before = try screen.snapshot()
            try expect(
                before.contains("baseline-A"),
                "first row missing at width \(columns)"
            )
            try expect(
                before.contains("baseline-B"),
                "second row missing at width \(columns)"
            )

            let unchangedSequence = renderer.encode(initial)
            try expect(
                !unchangedSequence.contains("baseline-A"),
                "unchanged row was re-encoded at width \(columns)"
            )
            screen.feed(unchangedSequence)

            var updated = TerminalFrame(
                rows: rows,
                columns: columns
            )
            updated.write(
                ["baseline-A", "changed-B"],
                in: region
            )

            let changedSequence = renderer.encode(updated)
            try expect(
                changedSequence.contains("changed-B"),
                "changed row was not encoded at width \(columns)"
            )
            screen.feed(changedSequence)

            let after = try screen.snapshot()
            try expect(
                after.contains("baseline-A"),
                "unchanged row was lost at width \(columns)"
            )
            try expect(
                after.contains("changed-B"),
                "changed row was not displayed at width \(columns)"
            )
            try expect(
                !after.contains("baseline-B"),
                "stale row remains at width \(columns)"
            )
        }
    }

    static func physicalGeometry() throws {
        for columns in [24, 40, 80] {
            try nestedBlockGeometry(columns: columns)
            try rightEdgeGeometry(columns: columns)
        }
    }

    static func nestedBlockGeometry(columns: Int) throws {
        let rowCount = 7
        let screen = try GhosttyTerminalScreen(
            columns: columns,
            rows: rowCount
        )
        var renderer = TerminalFrameRenderer()
        var frame = TerminalFrame(
            rows: rowCount,
            columns: columns
        )

        let block = TerminalInteractiveBlock(
            title: "Layout",
            body: "alpha beta gamma delta",
            horizontalPadding: 1
        )
        let blockColumns = columns - 4
        let rendered = block.render(width: blockColumns)

        try expect(
            rendered.count < rowCount - 1,
            "block does not fit at width \(columns)"
        )

        frame.write(
            rendered,
            in: TerminalRegion(
                top: 0,
                leading: 2,
                rows: rendered.count,
                columns: blockColumns
            )
        )
        frame.write(
            ["tail-marker"],
            in: TerminalRegion(
                top: rowCount - 1,
                leading: 0,
                rows: 1,
                columns: columns
            )
        )

        screen.feed(renderer.encode(frame))
        let lines = try screenRows(
            screen,
            expected: rowCount,
            context: "nested block width \(columns)"
        )

        try expect(
            lines[0].hasPrefix("  ╭") && lines[0].hasSuffix("╮"),
            "top border is misplaced at width \(columns)"
        )
        try expect(
            TerminalDisplay.width(of: lines[0]) == columns - 2,
            "top border has incorrect physical width at \(columns)"
        )
        try expect(
            lines[rendered.count - 1].hasPrefix("  ╰")
                && lines[rendered.count - 1].hasSuffix("╯"),
            "bottom border is misplaced at width \(columns)"
        )
        try expect(
            lines[rendered.count].isEmpty,
            "block overflowed into the following row at \(columns)"
        )
        try expect(
            lines[rowCount - 1] == "tail-marker",
            "bottom marker moved at width \(columns)"
        )
    }

    static func rightEdgeGeometry(columns: Int) throws {
        let screen = try GhosttyTerminalScreen(
            columns: columns,
            rows: 3
        )
        var renderer = TerminalFrameRenderer()
        var frame = TerminalFrame(
            rows: 3,
            columns: columns
        )

        let fullWidth = "L"
            + String(repeating: "x", count: columns - 2)
            + "R"

        frame.write(
            [fullWidth, "second-row", "end-marker"],
            in: TerminalRegion(
                rows: 3,
                columns: columns
            )
        )

        screen.feed(renderer.encode(frame))
        let lines = try screenRows(
            screen,
            expected: 3,
            context: "right edge width \(columns)"
        )

        try expect(
            lines[0] == fullWidth,
            "rightmost column was lost at width \(columns)"
        )
        try expect(
            lines[1] == "second-row",
            "right-edge wrap displaced the second row at \(columns)"
        )
        try expect(
            lines[2] == "end-marker",
            "right-edge wrap displaced the final row at \(columns)"
        )
    }

    static func screenRows(
        _ screen: GhosttyTerminalScreen,
        expected count: Int,
        context: String
    ) throws -> [String] {
        let output = try screen.snapshot()
        var lines = output.components(separatedBy: "\n")

        if lines.count == count + 1 && lines.last == "" {
            lines.removeLast()
        }

        try expect(
            lines.count == count,
            "\(context): expected \(count) rows, got \(lines.count)"
        )
        return lines
    }

    static func expect(_ condition: Bool, _ message: String) throws {
        if !condition {
            throw TestFailure.failed(message)
        }
    }

    enum TestFailure: Error {
        case failed(String)
    }
}
