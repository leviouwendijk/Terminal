public enum TerminalCommandLineEvent:
    Sendable,
    Codable,
    Hashable
{
    case changed
    case submitted(String)
    case cancelled
}

public struct TerminalCommandLine:
    Sendable,
    Hashable
{
    public private(set) var input: TerminalTextInput
    public private(set) var isActive: Bool
    public var prompt: String
    public private(set) var status: String?

    public init(
        input: TerminalTextInput = .init(),
        isActive: Bool = false,
        prompt: String = ":",
        status: String? = nil
    ) {
        self.input = input
        self.isActive = isActive
        self.prompt = prompt
        self.status = status
    }

    public var hasPresentation: Bool {
        isActive || status != nil
    }

    public var text: String {
        input.text
    }

    public mutating func begin(
        text: String = ""
    ) {
        status = nil
        input.replace(
            with: text
        )
        isActive = true
    }

    @discardableResult
    public mutating func handle(
        _ key: TerminalKey
    ) -> TerminalCommandLineEvent? {
        guard isActive else {
            return nil
        }

        switch input.handle(
            key
        ) {
        case .changed:
            return .changed

        case .submitRequested:
            let submitted = input.text
            isActive = false
            input.clear()
            return .submitted(
                submitted
            )

        case .cancelRequested:
            isActive = false
            input.clear()
            return .cancelled

        case nil:
            return nil
        }
    }

    public mutating func setStatus(
        _ status: String?
    ) {
        self.status = status
    }

    public mutating func clearStatus() {
        status = nil
    }

    public func render(
        into frame: inout TerminalFrame,
        in region: TerminalRegion,
        isFocused: Bool = true
    ) {
        guard !region.isEmpty else {
            return
        }

        if isActive {
            let value = prompt + input.text

            frame.write(
                TerminalDisplay.clipped(
                    value,
                    columns: region.columns
                ),
                in: TerminalRegion(
                    top: region.top,
                    leading: region.leading,
                    rows: 1,
                    columns: region.columns
                )
            )

            guard isFocused else {
                return
            }

            let beforeCursor = String(
                input.text.prefix(
                    input.cursorOffset
                )
            )
            let cursorColumns = TerminalDisplay.width(
                of: prompt + beforeCursor
            )

            frame.placeCursor(
                row: region.top,
                column: region.leading
                    + min(
                        max(
                            0,
                            region.columns - 1
                        ),
                        cursorColumns
                    ),
                shape: .bar
            )

            return
        }

        guard let status else {
            return
        }

        frame.write(
            TerminalStyle.dim.apply(
                TerminalDisplay.clipped(
                    status,
                    columns: region.columns
                )
            ),
            in: TerminalRegion(
                top: region.top,
                leading: region.leading,
                rows: 1,
                columns: region.columns
            )
        )
    }
}
