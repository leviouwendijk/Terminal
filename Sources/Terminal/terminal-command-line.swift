import Swim

public struct TerminalCommandLine:
    Sendable,
    Hashable
{
    public private(set) var interaction: Swim.ExCommandLine
    public var prompt: String
    public private(set) var status: String?

    public init(
        interaction: Swim.ExCommandLine = .init(),
        prompt: String = ":",
        status: String? = nil
    ) {
        self.interaction = interaction
        self.prompt = prompt
        self.status = status
    }

    public var isActive: Bool {
        interaction.isActive
    }

    public var hasPresentation: Bool {
        interaction.isActive
            || status != nil
    }

    public var text: String {
        interaction.text
    }

    public mutating func begin() {
        status = nil
        interaction.begin()
    }

    @discardableResult
    public mutating func handle(
        _ key: TerminalKey
    ) -> Swim.ExCommandLineResult {
        interaction.handle(
            key.swimInput
        )
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

        if interaction.isActive {
            let value = prompt + interaction.text

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

            let cursorColumns = TerminalDisplay.width(
                of: prompt + interaction.textBeforeCursor
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
