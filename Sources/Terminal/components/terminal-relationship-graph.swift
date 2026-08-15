public struct TerminalRelationshipGraphStyle:
    Sendable,
    Hashable
{
    public var heading: TerminalStyle
    public var input: TerminalStyle
    public var output: TerminalStyle
    public var connector: TerminalStyle

    public init(
        heading: TerminalStyle = .bold,
        input: TerminalStyle = .none,
        output: TerminalStyle = .none,
        connector: TerminalStyle = .dim
    ) {
        self.heading = heading
        self.input = input
        self.output = output
        self.connector = connector
    }

    public static let standard =
        TerminalRelationshipGraphStyle()

    public static let plain =
        TerminalRelationshipGraphStyle(
            heading: .none,
            input: .none,
            output: .none,
            connector: .none
        )
}

public struct TerminalRelationshipGraph:
    Sendable,
    Hashable
{
    public struct Edge:
        Sendable,
        Hashable
    {
        public let input: String
        public let output: String

        public init(
            input: String,
            output: String
        ) {
            self.input = input
            self.output = output
        }
    }

    public var edges: [Edge]
    public var inputTitle: String
    public var outputTitle: String
    public var style:
        TerminalRelationshipGraphStyle

    public init(
        edges: [Edge],
        inputTitle: String = "Inputs",
        outputTitle: String = "Outputs",
        style:
            TerminalRelationshipGraphStyle =
                .standard
    ) {
        self.edges = edges
        self.inputTitle = inputTitle
        self.outputTitle = outputTitle
        self.style = style
    }

    public func render(
        stream:
            TerminalStream =
                .standardError
    ) -> String {
        render(
            width:
                Terminal.size(
                    for: stream
                ).columns
        )
    }

    public func render(
        width: Int
    ) -> String {
        let edges =
            uniqueEdges()

        guard !edges.isEmpty else {
            return ""
        }

        guard width >= 44 else {
            return compact(
                edges
            )
        }

        let groups =
            groups(
                for: edges
            )

        let maximumInputWidth =
            groups
            .flatMap(\.inputs)
            .map(\.count)
            .max()
            ?? 1

        let maximumOutputWidth =
            groups
            .flatMap(\.outputs)
            .map(\.count)
            .max()
            ?? 1

        let preferred =
            Geometry(
                sourceRun: 12,
                branchGap: 6,
                outputRun: 16
            )

        let preferredWidth =
            maximumInputWidth
            + preferred.labelOffset
            + maximumOutputWidth

        let geometry =
            preferredWidth <= width
            ? preferred
            : Geometry(
                sourceRun: 4,
                branchGap: 2,
                outputRun: 8
            )

        let labelBudget =
            max(
                2,
                width
                    - geometry.labelOffset
            )

        var outputWidth =
            min(
                maximumOutputWidth,
                max(
                    1,
                    labelBudget / 2
                )
            )

        let inputWidth =
            min(
                maximumInputWidth,
                max(
                    1,
                    labelBudget
                        - outputWidth
                )
            )

        outputWidth =
            min(
                maximumOutputWidth,
                max(
                    1,
                    labelBudget
                        - inputWidth
                )
            )

        let outputColumn =
            inputWidth
            + geometry.labelOffset

        var lines = [
            heading(
                outputColumn:
                    outputColumn
            ),
            "",
        ]

        for (
            index,
            group
        ) in groups.enumerated() {
            if index > 0 {
                lines.append("")
            }

            lines.append(
                contentsOf:
                    render(
                        group,
                        inputWidth:
                            inputWidth,
                        outputWidth:
                            outputWidth,
                        geometry:
                            geometry
                    )
            )
        }

        return lines.joined(
            separator: "\n"
        )
    }
}

private extension TerminalRelationshipGraph {
    struct Group {
        var inputs: [String]
        let outputs: [String]
        let outputSet: Set<String>
    }

    struct Geometry {
        let sourceRun: Int
        let branchGap: Int
        let outputRun: Int

        var branchColumn: Int {
            sourceRun
                + 1
                + branchGap
        }

        var arrowColumn: Int {
            branchColumn
                + 1
                + outputRun
        }

        var labelOffset: Int {
            1
                + arrowColumn
                + 2
        }
    }

    func uniqueEdges() -> [Edge] {
        var seen =
            Set<Edge>()

        return edges.filter {
            seen.insert(
                $0
            ).inserted
        }
    }

    func groups(
        for edges: [Edge]
    ) -> [Group] {
        var inputOrder: [String] = []

        var outputsByInput:
            [String: [String]] = [:]

        for edge in edges {
            if outputsByInput[
                edge.input
            ] == nil {
                inputOrder.append(
                    edge.input
                )

                outputsByInput[
                    edge.input
                ] = []
            }

            if outputsByInput[
                edge.input
            ]?.contains(
                edge.output
            ) == false {
                outputsByInput[
                    edge.input
                ]?.append(
                    edge.output
                )
            }
        }

        var groups: [Group] = []

        for input in inputOrder {
            let outputs =
                outputsByInput[input]
                ?? []

            let outputSet =
                Set(
                    outputs
                )

            if let index =
                groups.firstIndex(
                    where: {
                        $0.outputSet
                            == outputSet
                    }
                )
            {
                groups[
                    index
                ].inputs.append(
                    input
                )
            } else {
                groups.append(
                    Group(
                        inputs: [
                            input,
                        ],
                        outputs:
                            outputs,
                        outputSet:
                            outputSet
                    )
                )
            }
        }

        return groups
    }

    func render(
        _ group: Group,
        inputWidth: Int,
        outputWidth: Int,
        geometry: Geometry
    ) -> [String] {
        let inputCount =
            group.inputs.count

        let outputCount =
            group.outputs.count

        guard
            inputCount > 0,
            outputCount > 0
        else {
            return []
        }

        let branchRow =
            (
                inputCount - 1
            ) / 2

        var lines: [String] = []

        for row in 0..<inputCount {
            let input =
                tail(
                    group.inputs[
                        row
                    ],
                    width:
                        inputWidth
                )

            let output =
                row == branchRow
                ? tail(
                    group.outputs[0],
                    width:
                        outputWidth
                )
                : nil

            lines.append(
                line(
                    input: input,
                    output: output,
                    inputWidth:
                        inputWidth,
                    connector:
                        inputConnector(
                            row: row,
                            inputCount:
                                inputCount,
                            outputCount:
                                outputCount,
                            branchRow:
                                branchRow,
                            geometry:
                                geometry
                        )
                )
            )
        }

        for outputIndex
        in group
            .outputs
            .indices
            .dropFirst()
        {
            let final =
                outputIndex
                == group.outputs
                    .indices
                    .last

            let connector =
                String(
                    repeating: " ",
                    count:
                        geometry
                        .branchColumn
                )
                + (
                    final
                    ? "└"
                    : "├"
                )
                + String(
                    repeating: "─",
                    count:
                        geometry
                        .outputRun
                )
                + "▶"

            lines.append(
                line(
                    input: "",
                    output:
                        tail(
                            group.outputs[
                                outputIndex
                            ],
                            width:
                                outputWidth
                        ),
                    inputWidth:
                        inputWidth,
                    connector:
                        connector
                )
            )
        }

        return lines
    }

    func inputConnector(
        row: Int,
        inputCount: Int,
        outputCount: Int,
        branchRow: Int,
        geometry: Geometry
    ) -> String {
        if inputCount == 1 {
            if outputCount == 1 {
                return String(
                    repeating: "─",
                    count:
                        geometry
                        .arrowColumn
                )
                    + "▶"
            }

            return String(
                repeating: "─",
                count:
                    geometry
                    .branchColumn
            )
                + "┬"
                + String(
                    repeating: "─",
                    count:
                        geometry
                        .outputRun
                )
                + "▶"
        }

        let left =
            String(
                repeating: "─",
                count:
                    geometry
                    .sourceRun
            )

        let merge =
            mergeJunction(
                row: row,
                inputCount:
                    inputCount,
                branchRow:
                    branchRow
            )

        guard
            row == branchRow
        else {
            if
                outputCount > 1,
                row > branchRow
            {
                return left
                    + String(
                        merge
                    )
                    + String(
                        repeating: " ",
                        count:
                            geometry
                            .branchGap
                    )
                    + "│"
            }

            return left
                + String(
                    merge
                )
        }

        if outputCount == 1 {
            return left
                + String(
                    merge
                )
                + String(
                    repeating: "─",
                    count:
                        geometry
                        .branchGap
                        + 1
                        + geometry
                            .outputRun
                )
                + "▶"
        }

        return left
            + String(
                merge
            )
            + String(
                repeating: "─",
                count:
                    geometry
                    .branchGap
            )
            + "┬"
            + String(
                repeating: "─",
                count:
                    geometry
                    .outputRun
            )
            + "▶"
    }

    func mergeJunction(
        row: Int,
        inputCount: Int,
        branchRow: Int
    ) -> Character {
        if row == branchRow {
            switch (
                row > 0,
                row < inputCount - 1
            ) {
            case (
                true,
                true
            ):
                return "┼"

            case (
                false,
                true
            ):
                return "┬"

            case (
                true,
                false
            ):
                return "┴"

            case (
                false,
                false
            ):
                return "─"
            }
        }

        if row == 0 {
            return "┐"
        }

        if row
            == inputCount - 1
        {
            return "┘"
        }

        return "┤"
    }

    func line(
        input: String,
        output: String?,
        inputWidth: Int,
        connector: String
    ) -> String {
        let padding =
            String(
                repeating: " ",
                count:
                    inputWidth
                    - input.count
            )

        let inputText =
            input.isEmpty
            ? ""
            : style.input.apply(
                input
            )

        let outputText =
            output.map(
                style.output.apply
            )
            ?? ""

        return inputText
            + padding
            + " "
            + style.connector.apply(
                connector
            )
            + (
                output == nil
                ? ""
                : " " + outputText
            )
    }

    func heading(
        outputColumn: Int
    ) -> String {
        style.heading.apply(
            inputTitle
        )
            + String(
                repeating: " ",
                count:
                    max(
                        1,
                        outputColumn
                            - 1
                            - inputTitle.count
                    )
            )
            + style.heading.apply(
                outputTitle
            )
    }

    func compact(
        _ edges: [Edge]
    ) -> String {
        var lines = [
            style.heading.apply(
                inputTitle
            )
                + " → "
                + style.heading.apply(
                    outputTitle
                ),
            "",
        ]

        for edge in edges {
            lines.append(
                style.input.apply(
                    edge.input
                )
                    + style
                        .connector
                        .apply(
                            " → "
                        )
                    + style.output.apply(
                        edge.output
                    )
            )
        }

        return lines.joined(
            separator: "\n"
        )
    }

    func tail(
        _ text: String,
        width: Int
    ) -> String {
        guard width > 0 else {
            return ""
        }

        guard
            text.count > width
        else {
            return text
        }

        guard width > 1 else {
            return "…"
        }

        return "…"
            + String(
                text.suffix(
                    width - 1
                )
            )
    }
}
