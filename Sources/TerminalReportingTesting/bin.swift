import DSL
import Foundation
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
        try expect(wide.contains("#") && wide.contains("<"), "Positive and negative bar marks")
        try expect(wide.contains("▁") && wide.contains("█"), "Ordered line sparkline")
        try expect(wide.contains("Mar: —"), "Missing chart point is not zero")
        try expect(document.datasets[0].rows[0].sources[0].identifier == "1", "Original provenance remains")
        for width in [8, 13, 27, 70] {
            let rows = renderer.rows(document, columns: width)
            try expect(rows.allSatisfy { TerminalDisplay.width(of: $0) <= width }, "Width \(width)")
        }
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
        print("TerminalReporting smoke: passed")
    }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw SmokeFailure.failed(message) }
    }
}
