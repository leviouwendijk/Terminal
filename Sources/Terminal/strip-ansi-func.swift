public func stripANSI(_ string: String) -> String {
    return string
        .replacingOccurrences(
            of: "\u{001B}\\[[0-9;]*[a-zA-Z]", 
            with: "", 
            options: .regularExpression
        )
}
