import Terminal

enum TerminalRelationshipGraphSmoke {
    enum SmokeError:
        Error
    {
        case unexpectedOutput
    }

    static func run() throws {
        let graph =
            TerminalRelationshipGraph(
                edges: [
                    .init(
                        input: "A.swift",
                        output: "foo.txt"
                    ),
                    .init(
                        input: "A.swift",
                        output: "all.txt"
                    ),
                    .init(
                        input: "B.swift",
                        output: "foo.txt"
                    ),
                    .init(
                        input: "B.swift",
                        output: "all.txt"
                    ),
                    .init(
                        input: "C.swift",
                        output: "foo.txt"
                    ),
                    .init(
                        input: "C.swift",
                        output: "all.txt"
                    ),
                    .init(
                        input: "D.swift",
                        output: "bar.txt"
                    ),
                    .init(
                        input: "D.swift",
                        output: "all.txt"
                    ),
                ],
                inputTitle: "Sources",
                outputTitle: "Outputs",
                style: .plain
            )

        let rendered =
            graph.render(
                width: 80
            )

        let expected =
            """
            Sources                                      Outputs

            A.swift ────────────┐
            B.swift ────────────┼──────┬────────────────▶ foo.txt
            C.swift ────────────┘      │
                                       └────────────────▶ all.txt

            D.swift ───────────────────┬────────────────▶ bar.txt
                                       └────────────────▶ all.txt
            """

        guard
            rendered == expected
        else {
            Terminal.write(
                "Unexpected relationship graph:\n\(rendered)\n",
                to: .standardError
            )

            throw SmokeError
                .unexpectedOutput
        }

        print(
            rendered
        )

        print(
            "relationship graph smoke passed"
        )
    }
}
