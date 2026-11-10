/// Terminal-cell raster with edge ownership and reserved presentation cells.
/// Orthogonal lines use box drawing; diagonals use 2x4 Braille subcells.
struct TerminalGraphCanvas<EdgeID: Hashable> {
    typealias Point = TerminalGraphStroke.Point

    let columns: Int
    let rows: Int

    private var strokes: [[UInt8]]
    private var owners: [Int: [EdgeID: UInt8]] = [:]
    private var dots: [Int: [EdgeID: UInt8]] = [:]
    private var nodes: [Int: Character] = [:]
    private var annotations: [Int: Character] = [:]
    private var arrows: [Int: Character] = [:]
    private var arrowPositions: [Point] = []
    private var junctions: [(point: Point, incident: Set<EdgeID>)] = []

    init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        strokes = Array(repeating: Array(repeating: 0, count: columns), count: rows)
    }

    private func index(_ point: Point) -> Int { point.row * columns + point.column }

    private func contains(_ point: Point) -> Bool {
        point.row >= 0 && point.row < rows && point.column >= 0 && point.column < columns
    }

    /// Returns occupied terminal cells in edge traversal order.
    mutating func trace(_ edge: EdgeID, from start: Point, to end: Point) -> [Point] {
        guard contains(start), contains(end) else { return [] }
        let dr = end.row - start.row
        let dc = end.column - start.column
        if dr != 0 && dc != 0 {
            return diagonal(edge, from: start, to: end)
        }
        guard dr != 0 || dc != 0 else { return [start] }

        var recorded: [(Point, UInt8)] = []
        TerminalGraphStroke.trace(from: start, to: end, into: &strokes) {
            recorded.append(($0, $1))
        }
        for (point, mask) in recorded {
            owners[index(point), default: [:]][edge, default: 0] |= mask
        }
        let steps = max(abs(dr), abs(dc))
        let rowStep = dr == 0 ? 0 : dr / abs(dr)
        let columnStep = dc == 0 ? 0 : dc / abs(dc)
        return (0...steps).map {
            Point(row: start.row + rowStep * $0, column: start.column + columnStep * $0)
        }
    }

    private mutating func diagonal(_ edge: EdgeID, from start: Point, to end: Point) -> [Point] {
        let x0 = start.column * 2 + 1
        let y0 = start.row * 4 + 2
        let dx = (end.column - start.column) * 2
        let dy = (end.row - start.row) * 4
        let steps = max(abs(dx), abs(dy))
        var route: [Point] = []
        var prior: Point?
        for step in 0...steps {
            let fraction = Double(step) / Double(steps)
            let px = x0 + Int((Double(dx) * fraction).rounded())
            let py = y0 + Int((Double(dy) * fraction).rounded())
            let point = Point(row: py / 4, column: px / 2)
            guard contains(point) else { continue }
            let dot = Self.dot(column: px % 2, row: py % 4)
            dots[index(point), default: [:]][edge, default: 0] |= dot
            if prior != point {
                route.append(point)
                prior = point
            }
        }
        return route
    }

    private static func dot(column: Int, row: Int) -> UInt8 {
        let bit: [[UInt8]] = [[1, 2, 4, 64], [8, 16, 32, 128]]
        return bit[column][row]
    }

    mutating func reserveNode(_ text: String, at center: Point) {
        let start = center.column - text.count / 2
        for (offset, glyph) in text.enumerated() {
            let point = Point(row: center.row, column: start + offset)
            guard contains(point) else { continue }
            nodes[index(point)] = glyph
        }
    }

    mutating func registerJunction(at point: Point, incident: Set<EdgeID>) {
        junctions.append((point, incident))
    }

    @discardableResult
    mutating func placeArrow(
        _ glyph: Character,
        for edge: EdgeID,
        along candidates: [Point]
    ) -> Bool {
        for point in candidates where contains(point) {
            let cell = index(point)
            guard nodes[cell] == nil, annotations[cell] == nil, arrows[cell] == nil,
                  (owners[cell]?[edge] ?? 0) != 0 || (dots[cell]?[edge] ?? 0) != 0,
                  !isCrossing(at: cell) else { continue }
            guard !arrowPositions.contains(where: {
                abs($0.row - point.row) <= 2 && abs($0.column - point.column) <= 3
            }) else { continue }
            arrows[cell] = glyph
            arrowPositions.append(point)
            return true
        }
        return false
    }

    @discardableResult
    mutating func placeLabel(_ text: String, near route: [Point]) -> Bool {
        guard !text.isEmpty else { return true }
        let middle = route.count / 2
        let candidates = route.indices.sorted {
            let a = abs($0 - middle)
            let b = abs($1 - middle)
            return a == b ? $0 < $1 : a < b
        }
        for offset in candidates {
            let point = route[offset]
            for column in [point.column + 2, point.column - text.count - 2] {
                guard column >= 0 && column + text.count <= columns else { continue }
                let cells = (column..<(column + text.count)).map {
                    index(Point(row: point.row, column: $0))
                }
                guard cells.allSatisfy({
                    nodes[$0] == nil && annotations[$0] == nil && arrows[$0] == nil &&
                    strokes[$0 / columns][$0 % columns] == 0 && dots[$0] == nil
                }) else { continue }
                for (index, glyph) in text.enumerated() {
                    annotations[cells[index]] = glyph
                }
                return true
            }
        }
        return false
    }

    private func isCrossing(at cell: Int) -> Bool {
        let orthogonal = owners[cell] ?? [:]
        let diagonal = dots[cell] ?? [:]
        let point = Point(row: cell / columns, column: cell % columns)
        func unrelated(_ a: EdgeID, _ b: EdgeID) -> Bool {
            guard a != b else { return false }
            return !junctions.contains { junction in
                abs(junction.point.row - point.row) <= 1 &&
                abs(junction.point.column - point.column) <= 1 &&
                junction.incident.contains(a) && junction.incident.contains(b)
            }
        }
        let horizontal = orthogonal.filter { ($0.value & 10) == 10 }.map(\.key)
        let vertical = orthogonal.filter { ($0.value & 5) == 5 }.map(\.key)
        if horizontal.contains(where: { h in vertical.contains(where: { unrelated(h, $0) }) }) {
            return true
        }
        for (first, marks) in diagonal {
            if diagonal.contains(where: { unrelated(first, $0.key) && ($0.value & marks) != 0 }) {
                return true
            }
            if orthogonal.keys.contains(where: { unrelated(first, $0) }) { return true }
        }
        return false
    }

    func lines() -> [String] {
        (0..<rows).map { row in
            var glyphs: [Character] = []
            for column in 0..<columns {
                let cell = row * columns + column
                if let node = nodes[cell] {
                    glyphs.append(node)
                } else if let annotation = annotations[cell] {
                    glyphs.append(annotation)
                } else if let arrow = arrows[cell] {
                    glyphs.append(arrow)
                } else if isCrossing(at: cell) {
                    glyphs.append("╳")
                } else if strokes[row][column] != 0 {
                    glyphs.append(TerminalGraphStroke.glyph(strokes[row][column]))
                } else if let dotted = dots[cell] {
                    let mask = dotted.values.reduce(UInt8(0), |)
                    let scalar = UnicodeScalar(0x2800 + Int(mask))
                    glyphs.append(scalar.map { Character(String($0)) } ?? "·")
                } else {
                    glyphs.append(" ")
                }
            }
            guard let last = glyphs.lastIndex(where: { $0 != " " }) else { return "" }
            return String(glyphs[...last])
        }
    }
}
