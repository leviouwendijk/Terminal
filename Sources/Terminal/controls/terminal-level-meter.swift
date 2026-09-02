public struct TerminalLevelMeter:
    Sendable,
    Hashable
{
    public var values: [Double]
    public var capacity: Int

    public init(
        values: [Double] = [],
        capacity: Int = 32
    ) {
        self.capacity = max(
            1,
            capacity
        )
        self.values = Array(
            values.suffix(
                self.capacity
            )
        )
    }

    public mutating func append(
        _ value: Double
    ) {
        values.append(
            clamped(
                value
            )
        )

        if values.count > capacity {
            values.removeFirst(
                values.count - capacity
            )
        }
    }

    public mutating func reset() {
        values.removeAll(
            keepingCapacity: true
        )
    }

    public func render(
        width: Int? = nil
    ) -> String {
        let visible: ArraySlice<Double>

        if let width {
            visible = values.suffix(
                max(
                    0,
                    width
                )
            )
        } else {
            visible = values[...]
        }

        return String(
            visible.map(
                glyph
            )
        )
    }

    private func glyph(
        _ value: Double
    ) -> Character {
        let glyphs = Array(
            "▁▂▃▄▅▆▇█"
        )
        let index = Int(
            (
                clamped(
                    value
                )
                * Double(
                    glyphs.count - 1
                )
            ).rounded()
        )

        return glyphs[
            max(
                0,
                min(
                    glyphs.count - 1,
                    index
                )
            )
        ]
    }

    private func clamped(
        _ value: Double
    ) -> Double {
        min(
            1,
            max(
                0,
                value
            )
        )
    }
}
