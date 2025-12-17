import Foundation

public struct ColorableString: Sendable {
    public let selection: Set<String>
    public let colors: Set<ANSIColor>
    
    public init(
        selection: Set<String>,
        colors: Set<ANSIColor>
    ) {
        self.selection = selection
        self.colors = colors
    }

    public func paint(in string: String) -> String {
        var painted = string
        for s in selection.sorted(by: { $0.count > $1.count }) {
            for c in colors {
                painted = painted
                .replacingOccurrences(of: s, with: s.ansi(c))
            }
        }
        return painted
    }
}

extension String {
    public func paint(_ selections: [ColorableString]) -> String {
        var painted = self
        for s in selections {
            painted = s.paint(in: painted)
        }
        return painted
    }
}
