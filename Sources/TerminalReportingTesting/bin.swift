import DSL
import Foundation
import Math
import Reporting
import Search
import Terminal
import TerminalReporting

private enum SmokeFailure: Error {
    case failed(String)
}

@main
struct TerminalReportingSmoke {
    static func main() throws {
        let dataset = try ReportDataset(
            id: "monthly",
            columns: [
                .init("month", kind: .text),
                .init("amount", kind: .decimal),
            ],
            rows: [
                .init(values: [.text("Jan"), .decimal(10)], sources: [.init(namespace: "entry", identifier: "1")]),
                .init(values: [.text("Feb"), .decimal(-5)], sources: [.init(namespace: "entry", identifier: "2")]),
                .init(values: [.text("Mar"), nil]),
            ],
            coverage: .complete
        )
        let document = try ReportDocument(
            title: "Monthly totals",
            datasets: [dataset],
            blocks: [
                .narrative(.paragraph([.text("Deterministic overview")])),
                .table(.init(dataset: "monthly", columns: ["month", "amount"], title: "Values")),
                .chart(.init(dataset: "monthly", kind: .bar, x: "month", y: "amount")),
                .chart(.init(dataset: "monthly", kind: .line, x: "month", y: "amount")),
            ]
        )
        let renderer = TerminalReporting.Renderer()
        let wide = renderer.render(document, columns: 70)
        try expect(wide.contains("Monthly totals"), "Title")
        try expect(wide.contains("Deterministic overview"), "DSL narrative")
        try expect(wide.contains("Jan") && wide.contains("-5"), "Table and signed numerics")
        try expect(wide.contains("█") && wide.contains("▇"), "Positive and negative Unicode bars")
        try expect(wide.contains("▁") && wide.contains("█"), "Ordered line sparkline")
        try expect(wide.contains("Mar") && wide.contains("—"), "Missing chart point is not zero")
        try expect(document.datasets[0].rows[0].sources[0].identifier == "1", "Original provenance remains")
        for width in [8, 13, 27, 70] {
            let rows = renderer.rows(document, columns: width)
            try expect(rows.allSatisfy { TerminalDisplay.width(of: $0) <= width }, "Width \(width)")
        }
        let bodyOnly = renderer.rows(document, columns: 70, includeTitle: false)
        try expect(!bodyOnly.contains("Monthly totals"), "Caller can own the title")
        try expect(bodyOnly.contains("Values"), "Removing title preserves blocks")
        let zeroDataset = try ReportDataset(
            id: "zero",
            columns: [.init("label", kind: .text), .init("amount", kind: .decimal)],
            rows: [
                .init(values: [.text("A"), .decimal(0)]),
                .init(values: [.text("B"), .decimal(0)]),
            ],
            coverage: .complete
        )
        let zeroDocument = try ReportDocument(
            title: "Zero", datasets: [zeroDataset],
            blocks: [.chart(.init(dataset: "zero", kind: .bar, x: "label", y: "amount")),
                     .chart(.init(dataset: "zero", kind: .line, x: "label", y: "amount"))]
        )
        let zeroRows = renderer.rows(zeroDocument, columns: 45)
        try expect(zeroRows.contains(where: { $0.contains("│") }), "All-zero bar has baseline")
        try expect(zeroRows.contains(where: { $0.contains("▄▄") }), "Constant line has defined flat glyph")
        let exactDataset = try ReportDataset(
            id: "exact", columns: [.init("label", kind: .text), .init("value", kind: .decimal)],
            rows: [
                .init(values: [.text("Precise"), .decimal(try DecimalArithmetic.parse("1000000000000000000.125"))])
            ], coverage: .complete
        )
        let exactDocument = try ReportDocument(
            title: "Exact", datasets: [exactDataset],
            blocks: [.chart(.init(dataset: "exact", kind: .bar, x: "label", y: "value"))]
        )
        try expect(renderer.render(exactDocument, columns: 90).contains("1000000000000000000.125"),
                   "Chart prints exact decimal, not Double")

        let partial = try ReportDataset(
            id: "partial", columns: [.init("amount", kind: .integer)],
            rows: [.init(values: [.integer(3)])],
            coverage: .partial(offset: 0, total: 9)
        )
        let partialReport = try ReportDocument(
            title: "Partial", datasets: [partial],
            blocks: [.table(.init(dataset: "partial", columns: ["amount"]))]
        )
        try expect(renderer.render(partialReport, columns: 70).contains("partial data"), "Coverage warning")
        let longDataset = try ReportDataset(
            id: "long",
            columns: [.init("x", kind: .text), .init("y", kind: .integer)],
            rows: (0..<20).map { i in .init(values: [.text("point\(i)"), .integer(Int64(i))]) },
            coverage: .complete
        )
        let longReport = try ReportDocument(
            title: "Long", datasets: [longDataset],
            blocks: [.chart(.init(dataset: "long", kind: .line, x: "x", y: "y"))]
        )
        try expect(renderer.render(longReport, columns: 12).contains("point19"), "No silent point omission")

        // 2026-11-18 08:00 Europe/Amsterdam
        let morning = Date(timeIntervalSince1970: 1_763_449_200)
        let hour: TimeInterval = 3600
        let leviSpans: [ReportBlock.Timeline.Span] = [
            .init(start: morning, end: morning + hour, mark: .occupied, label: "Standup"),
            .init(start: morning + 2 * hour, end: morning + 3 * hour, mark: .highlight, label: "Proposed"),
            .init(start: morning + 6 * hour, end: morning + 8 * hour, mark: .reserved),
        ]
        let annaSpans: [ReportBlock.Timeline.Span] = [
            .init(start: morning + hour, end: morning + 4 * hour, mark: .available),
        ]
        let timeline = ReportBlock.Timeline(
            start: morning, end: morning + 10 * hour, timeZone: "Europe/Amsterdam",
            lanes: [.init(label: "Levi", spans: leviSpans), .init(label: "Anna", spans: annaSpans)]
        )
        let facts = ReportBlock.Facts(facts: [.init("Recommended", "Tue 18 Nov 10:00–11:00"), .init("Placement", "offered")])
        let callout = ReportBlock.Callout(tone: .warning, title: "Gaps", content: .paragraph([.text("No location given")]))
        let graph = ReportBlock.Graph(
            nodes: [.init(id: "a", label: "Request"), .init(id: "b", label: "Proposal")],
            edges: [.init(id: "ab", source: "a", destination: "b", label: "resolves")]
        )
        let blocks = try ReportDocument(
            title: "Proposal",
            datasets: [],
            blocks: [.facts(facts), .callout(callout), .timeline(timeline), .graph(graph)]
        )
        let rendered = renderer.render(blocks, columns: 72)
        try expect(rendered.contains("Recommended") && rendered.contains("10:00–11:00"), "Facts")
        try expect(rendered.contains("! Gaps") && rendered.contains("│ No location"), "Callout")
        try expect(rendered.contains("08") && rendered.contains("12"), "Hour axis in the timeline's zone")
        try expect(rendered.contains("▲") && rendered.contains("█") && rendered.contains("▒") && rendered.contains("░"), "Marks")
        try expect(rendered.contains("10:00–11:00 highlight · Proposed"), "Labeled spans listed")
        try expect(rendered.contains("Request") && rendered.contains("resolves"), "Graph block")
        let levi = renderer.rows(blocks, columns: 72).first { $0.hasPrefix("Levi") && $0.contains("│") } ?? ""
        try expect(levi.firstIndex(of: "▲")! > levi.firstIndex(of: "█")!, "Highlight after the standup")
        for width in [10, 24, 40, 72] {
            try expect(renderer.rows(blocks, columns: width).allSatisfy { TerminalDisplay.width(of: $0) <= width }, "Blocks fit width \(width)")
        }
        print("TerminalReporting smoke: passed")
    }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw SmokeFailure.failed(message) }
    }
}
