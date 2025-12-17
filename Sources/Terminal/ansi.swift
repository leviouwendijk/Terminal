import Foundation

public typealias ANSIColor = ANSICode

public enum ANSICode: String, Sendable {
    case reset = "\u{001B}[0m"

    // Basic Text Formatting
    case bold = "\u{001B}[1m"
    case dim = "\u{001B}[2m"
    case italic = "\u{001B}[3m"
    case underline = "\u{001B}[4m"
    case blink = "\u{001B}[5m"
    case inverse = "\u{001B}[7m"
    case hidden = "\u{001B}[8m"
    case strikethrough = "\u{001B}[9m"
    
    // Foreground Colors
    case black = "\u{001B}[30m"
    case red = "\u{001B}[31m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case blue = "\u{001B}[34m"
    case magenta = "\u{001B}[35m"
    case cyan = "\u{001B}[36m"
    case white = "\u{001B}[37m"
    case defaultText = "\u{001B}[39m"
    
    // Bright Foreground Colors
    case brightBlack = "\u{001B}[90m"
    case brightRed = "\u{001B}[91m"
    case brightGreen = "\u{001B}[92m"
    case brightYellow = "\u{001B}[93m"
    case brightBlue = "\u{001B}[94m"
    case brightMagenta = "\u{001B}[95m"
    case brightCyan = "\u{001B}[96m"
    case brightWhite = "\u{001B}[97m"
    
    // Background Colors
    case blackBackground = "\u{001B}[40m"
    case redBackground = "\u{001B}[41m"
    case greenBackground = "\u{001B}[42m"
    case yellowBackground = "\u{001B}[43m"
    case blueBackground = "\u{001B}[44m"
    case magentaBackground = "\u{001B}[45m"
    case cyanBackground = "\u{001B}[46m"
    case whiteBackground = "\u{001B}[47m"
    case defaultBackground = "\u{001B}[49m"
    
    // Bright Background Colors
    case brightBlackBackground = "\u{001B}[100m"
    case brightRedBackground = "\u{001B}[101m"
    case brightGreenBackground = "\u{001B}[102m"
    case brightYellowBackground = "\u{001B}[103m"
    case brightBlueBackground = "\u{001B}[104m"
    case brightMagentaBackground = "\u{001B}[105m"
    case brightCyanBackground = "\u{001B}[106m"
    case brightWhiteBackground = "\u{001B}[107m"
    
    // Cursor Control
    case cursorUp = "\u{001B}[{n}A"
    case cursorDown = "\u{001B}[{n}B"
    case cursorRight = "\u{001B}[{n}C"
    case cursorLeft = "\u{001B}[{n}D"
    case cursorPosition = "\u{001B}[{line};{column}H"
    case clearLine = "\u{001B}[2K"
    case clearScreen = "\u{001B}[2J"

    public static func rgb(_ r: Int,_ g: Int,_ b: Int, _ background: Bool = false) -> String {
        if !background {
            return "\u{001B}[38;2;\(r);\(g);\(b)m"
        } else {
            return "\u{001B}[48;2;\(r);\(g);\(b)m"
        }
    }
}

public protocol StringANSIFormattable {
    func ansi(_ colors: ANSIColor...) -> String
    func ansiRGB(_ r: Int, _ g: Int, _ b: Int, _ background: Bool) -> String
}

extension String: StringANSIFormattable {
    public func ansi(_ colors: ANSIColor...) -> String {
        let colorCodes = colors.map { $0.rawValue }.joined()
        return "\(colorCodes)\(self)\(ANSIColor.reset.rawValue)"
    }

    public func ansiRGB(_ r: Int, _ g: Int, _ b: Int, _ background: Bool = false) -> String {
        let colorCode = ANSIColor.rgb(r, g, b, background)
        return "\(colorCode)\(self)\(ANSIColor.reset.rawValue)"
    }
}

// OSC-8 links
public enum ANSITerminator: Sendable {
    case bel
    case st

    public var value: String {
        switch self {
        case .bel: return "\u{0007}"
        case .st:  return "\u{001B}\\"
        }
    }
}

public enum ANSILink {
    public static func osc8(url: String, label: String? = nil, terminator: ANSITerminator = .bel) -> String {
        let start = "\u{001B}]8;;\(url)\(terminator.value)"
        let end   = "\u{001B}]8;;\(terminator.value)"
        return "\(start)\(label ?? url)\(end)"
    }
}

public extension URL {
    func osc8(label: String? = nil, terminator: ANSITerminator = .bel) -> String {
        ANSILink.osc8(url: self.absoluteString, label: label, terminator: terminator)
    }
}

public extension String {
    var osc8: String { ANSILink.osc8(url: self) }

    func osc8(label: String? = nil, terminator: ANSITerminator = .bel) -> String {
        ANSILink.osc8(url: self, label: label, terminator: terminator)
    }
}

