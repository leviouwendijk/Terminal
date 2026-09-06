import ANSI

public struct TerminalStyle: Sendable, Hashable {
    public enum Color: Sendable, Hashable {
        case rgb(
            red: UInt8,
            green: UInt8,
            blue: UInt8
        )

        public static func hex(
            _ value: String
        ) -> Self? {
            let value = value.hasPrefix("#")
                ? String(
                    value.dropFirst()
                )
                : value

            guard value.count == 6,
                  let rgb = UInt32(
                    value,
                    radix: 16
                  )
            else {
                return nil
            }

            return .rgb(
                red: UInt8(
                    (rgb >> 16) & 0xff
                ),
                green: UInt8(
                    (rgb >> 8) & 0xff
                ),
                blue: UInt8(
                    rgb & 0xff
                )
            )
        }

        public func hex() -> String {
            switch self {
            case .rgb(
                let red,
                let green,
                let blue
            ):
                return "#"
                    + Self.hexComponent(
                        red
                    )
                    + Self.hexComponent(
                        green
                    )
                    + Self.hexComponent(
                        blue
                    )
            }
        }

        fileprivate func ansiSequence(
            background: Bool
        ) -> String {
            switch self {
            case .rgb(
                let red,
                let green,
                let blue
            ):
                return ANSIColor.rgb(
                    Int(red),
                    Int(green),
                    Int(blue),
                    background
                )
            }
        }

        private static func hexComponent(
            _ value: UInt8
        ) -> String {
            let component = String(
                value,
                radix: 16,
                uppercase: false
            )

            return component.count == 1
                ? "0" + component
                : component
        }
    }

    private enum Component: Sendable, Hashable {
        case ansi(ANSIColor)
        case foreground(Color)
        case background(Color)

        var ansiSequence: String {
            switch self {
            case .ansi(let code):
                return code.rawValue

            case .foreground(let color):
                return color.ansiSequence(
                    background: false
                )

            case .background(let color):
                return color.ansiSequence(
                    background: true
                )
            }
        }
    }

    private var components: [Component]

    public var codes: [ANSIColor] {
        get {
            components.compactMap { component in
                guard case .ansi(let code) = component else {
                    return nil
                }

                return code
            }
        }
        set {
            let colors = components.filter { component in
                switch component {
                case .ansi:
                    return false

                case .foreground,
                     .background:
                    return true
                }
            }

            components = newValue.map {
                .ansi(
                    $0
                )
            } + colors
        }
    }

    public var isEmpty: Bool {
        components.isEmpty
    }

    public init(
        _ codes: ANSIColor...
    ) {
        self.components = codes.map {
            .ansi(
                $0
            )
        }
    }

    public init(
        codes: [ANSIColor]
    ) {
        self.components = codes.map {
            .ansi(
                $0
            )
        }
    }

    public init(
        foreground: Color?,
        background: Color?,
        codes: [ANSIColor] = []
    ) {
        var components = codes.map {
            Component.ansi(
                $0
            )
        }

        if let foreground {
            components.append(
                .foreground(
                    foreground
                )
            )
        }

        if let background {
            components.append(
                .background(
                    background
                )
            )
        }

        self.components = components
    }

    public func merging(
        _ overlay: TerminalStyle
    ) -> TerminalStyle {
        TerminalStyle(
            components:
                components
                + overlay.components
        )
    }

    public func apply(
        _ text: String
    ) -> String {
        guard !components.isEmpty else {
            return text
        }

        let prefix = components
            .map(\.ansiSequence)
            .joined()

        return "\(prefix)\(text)\(ANSIColor.reset.rawValue)"
    }

    public func apply(
        lines: [String]
    ) -> [String] {
        lines.map {
            apply($0)
        }
    }

    public static let none = TerminalStyle()
    public static let bold = TerminalStyle(.bold)
    public static let dim = TerminalStyle(.dim)
}

private extension TerminalStyle {
    private init(
        components: [Component]
    ) {
        self.components = components
    }
}
