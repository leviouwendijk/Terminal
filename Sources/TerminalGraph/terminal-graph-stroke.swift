/// Shared orthogonal stroke rasterization for graph projections.
/// Mask bits: north = 1, east = 2, south = 4, west = 8.
enum TerminalGraphStroke {
    struct Point {
        let row: Int
        let column: Int

        init(row: Int, column: Int) {
            self.row = row
            self.column = column
        }
    }

    static func trace(
        from start: Point,
        to end: Point,
        into grid: inout [[UInt8]],
        record: ((Point, UInt8) -> Void)? = nil
    ) {
        let dr = end.row == start.row ? 0 : (end.row > start.row ? 1 : -1)
        let dc = end.column == start.column ? 0 : (end.column > start.column ? 1 : -1)
        let steps = max(abs(end.row - start.row), abs(end.column - start.column))
        guard (dr == 0) != (dc == 0) else { return }

        let forward: UInt8 = dr > 0 ? 4 : dr < 0 ? 1 : dc > 0 ? 2 : 8
        let reverse: UInt8 = dr > 0 ? 1 : dr < 0 ? 4 : dc > 0 ? 8 : 2
        for step in 0..<steps {
            let row = start.row + dr * step
            let column = start.column + dc * step
            grid[row][column] |= forward
            grid[row + dr][column + dc] |= reverse
            record?(Point(row: row, column: column), forward)
            record?(Point(row: row + dr, column: column + dc), reverse)
        }
    }

    /// Samples a straight diagonal in terminal-cell coordinates.
    /// The source and destination cells are both included.
    static func diagonalPoints(from start: Point, to end: Point) -> [Point] {
        let deltaRow = end.row - start.row
        let deltaColumn = end.column - start.column
        let steps = max(abs(deltaRow), abs(deltaColumn))
        guard deltaRow != 0 && deltaColumn != 0 else { return [] }

        var points: [Point] = []
        for index in 0...steps {
            let progress = Double(index) / Double(steps)
            let row = start.row + Int((Double(deltaRow) * progress).rounded())
            let column = start.column + Int((Double(deltaColumn) * progress).rounded())
            points.append(Point(row: row, column: column))
        }
        return points
    }

    static func glyph(_ mask: UInt8) -> Character {
        switch mask {
        case 1: "╵"
        case 2: "╶"
        case 3: "└"
        case 4: "╷"
        case 5: "│"
        case 6: "┌"
        case 7: "├"
        case 8: "╴"
        case 9: "┘"
        case 10: "─"
        case 11: "┴"
        case 12: "┐"
        case 13: "┤"
        case 14: "┬"
        case 15: "┼"
        default: " "
        }
    }
}
