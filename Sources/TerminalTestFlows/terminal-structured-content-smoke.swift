import DSL
import Terminal
import TerminalStructuredContent

enum TerminalStructuredContentSmoke {
    enum Failure: Error {
        case wordWrapping
        case collectionSpacing
        case inlineStyles
        case recursion
        case rolePresentation
        case leakedRole
        case width
    }

    static func run() throws {
        try wrapping()
        try collectionSpacing()
        try inlineStyles()
        try recursion()
        try roles()
        try width()
        print(sample())
    }

    private static func wrapping() throws {
        let rows = TerminalStructuredContent.Renderer().rows(
            .paragraph([.text("alpha beta gamma")]),
            columns: 10
        ).map(stripANSI)

        guard rows == ["alpha beta", "gamma"] else {
            throw Failure.wordWrapping
        }
    }

    private static func collectionSpacing() throws {
        var format = TerminalStructuredContent.Format.minimal
        format.block.collection.spacing = 2

        let rows = TerminalStructuredContent.Renderer(
            format: format
        ).rows(
            .collection([
                .paragraph([.text("first")]),
                .paragraph([.text("second")]),
            ]),
            columns: 20
        ).map(stripANSI)

        guard rows == [
            "first",
            "",
            "",
            "second",
        ] else {
            throw Failure.collectionSpacing
        }
    }

    private static func inlineStyles() throws {
        let row = TerminalStructuredContent.Renderer().rows(
            .paragraph([
                .text("Use "),
                .strong([.text("strong")]),
                .text(", "),
                .emphasis([.text("emphasis")]),
                .text(", and "),
                .code("code"),
                .text(".")
            ]),
            columns: 80
        ).first ?? ""

        guard stripANSI(row) == "Use strong, emphasis, and code.",
              row.contains(TerminalStyle.bold.apply("strong")),
              row.contains(TerminalStyle(.italic).apply("emphasis")),
              row.contains(TerminalStyle.dim.apply("code")) else {
            throw Failure.inlineStyles
        }
    }

    private static func recursion() throws {
        let quote = TerminalStructuredContent.Renderer().rows(
            .quote(
                .collection([
                    .paragraph([.text("quoted")]),
                    .code(language: "swift", source: "let value = 1")
                ])
            ),
            columns: 30
        )

        guard quote.count >= 4,
              quote.allSatisfy({ stripANSI($0).hasPrefix("│ ") }) else {
            throw Failure.recursion
        }

        let list = TerminalStructuredContent.Renderer().rows(
            .list(
                style: .ordered,
                items: [
                    .paragraph([.text("first")]),
                    .collection([
                        .paragraph([.text("second")]),
                        .list(
                            style: .unordered,
                            items: [.paragraph([.text("nested")])]
                        )
                    ])
                ]
            ),
            columns: 30
        ).map(stripANSI)

        guard list.first?.hasPrefix("1. first") == true,
              list.contains(where: { $0.hasPrefix("2. second") }),
              list.contains(where: { $0.contains("• nested") }) else {
            throw Failure.recursion
        }
    }

    private static func roles() throws {
        let role = StructuredContent.Role(rawValue: "test.example")
        var format = TerminalStructuredContent.Format.minimal
        format.block.group.roles.resolve = { candidate in
            candidate == role
                ? .init(titlePrefix: "Example", contentIndent: 2)
                : nil
        }

        let renderer = TerminalStructuredContent.Renderer(format: format)
        let rows = renderer.rows(
            .group(
                role: role,
                title: [.text("Nested API")],
                content: .paragraph([.text("body")])
            ),
            columns: 40
        ).map(stripANSI)

        guard rows.first == "Example: Nested API",
              rows.last == "  body" else {
            throw Failure.rolePresentation
        }

        let unknown = StructuredContent.Role(rawValue: "unknown.role")
        let fallback = renderer.render(
            .group(
                role: unknown,
                title: [.text("Fallback")],
                content: .paragraph([.text("body")])
            ),
            columns: 40
        )

        guard !fallback.contains(unknown.rawValue) else {
            throw Failure.leakedRole
        }
    }

    private static func width() throws {
        let rows = TerminalStructuredContent.Renderer().rows(
            sampleContent(),
            columns: 32
        )

        guard rows.allSatisfy({ TerminalDisplay.width(of: $0) <= 32 }) else {
            throw Failure.width
        }
    }

    private static func sample() -> String {
        var format = TerminalStructuredContent.Format.minimal
        format.block.group.roles["test.example"] = .init(
            titlePrefix: "Example",
            contentIndent: 2
        )

        return TerminalStructuredContent.Renderer(format: format).render(
            sampleContent(),
            columns: 64
        )
    }

    private static func sampleContent() -> StructuredContent {
        .collection([
            .group(
                role: nil,
                title: [.text("Structured content")],
                content: .paragraph([
                    .text("A sparse terminal projection with "),
                    .strong([.text("strong")]),
                    .text(", "),
                    .emphasis([.text("emphasis")]),
                    .text(", and "),
                    .code("inline code"),
                    .text(".")
                ])
            ),
            .quote(
                .paragraph([.text("Quotes remain recursive and visually quiet.")])
            ),
            .list(
                style: .unordered,
                items: [
                    .paragraph([.text("Lists accept complete structured-content items.")]),
                    .group(
                        role: "test.example",
                        title: [.text("Role formatting")],
                        content: .paragraph([
                            .text("Consumers can specialize semantic roles without teaching Terminal the domain.")
                        ])
                    )
                ]
            ),
            .code(
                language: "swift",
                source:
                    "let format = TerminalStructuredContent.Format.minimal\n"
                    + "let renderer = TerminalStructuredContent.Renderer(format: format)"
            )
        ])
    }
}
