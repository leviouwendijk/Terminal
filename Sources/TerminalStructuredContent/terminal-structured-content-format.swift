import DSL
import Terminal

public enum TerminalStructuredContent {}

public extension TerminalStructuredContent {
    struct Format: Sendable {
        public var inline: Inline
        public var block: Block

        public init(
            inline: Inline = .init(),
            block: Block = .init()
        ) {
            self.inline = inline
            self.block = block
        }

        public static var minimal: Self { .init() }
    }
}

public extension TerminalStructuredContent.Format {
    struct Inline: Sendable, Hashable {
        public var text: TerminalStyle
        public var code: TerminalStyle
        public var emphasis: TerminalStyle
        public var strong: TerminalStyle

        public init(
            text: TerminalStyle = .none,
            code: TerminalStyle = .dim,
            emphasis: TerminalStyle = .init(.italic),
            strong: TerminalStyle = .bold
        ) {
            self.text = text
            self.code = code
            self.emphasis = emphasis
            self.strong = strong
        }
    }

    struct Block: Sendable {
        public var collection: Collection
        public var paragraph: Paragraph
        public var code: Code
        public var quote: Quote
        public var list: List
        public var group: Group

        public init(
            collection: Collection = .init(),
            paragraph: Paragraph = .init(),
            code: Code = .init(),
            quote: Quote = .init(),
            list: List = .init(),
            group: Group = .init()
        ) {
            self.collection = collection
            self.paragraph = paragraph
            self.code = code
            self.quote = quote
            self.list = list
            self.group = group
        }
    }
}

public extension TerminalStructuredContent.Format.Block {
    struct Collection: Sendable, Hashable {
        public var spacing: Int

        public init(
            spacing: Int = 1
        ) {
            self.spacing = max(
                0,
                spacing
            )
        }
    }

    struct Paragraph: Sendable, Hashable {
        public var style: TerminalStyle
        public init(style: TerminalStyle = .none) { self.style = style }
    }

    struct Code: Sendable, Hashable {
        public var indent: Int
        public var languageStyle: TerminalStyle
        public var sourceStyle: TerminalStyle

        public init(
            indent: Int = 2,
            languageStyle: TerminalStyle = .dim,
            sourceStyle: TerminalStyle = .none
        ) {
            self.indent = max(0, indent)
            self.languageStyle = languageStyle
            self.sourceStyle = sourceStyle
        }
    }

    struct Quote: Sendable, Hashable {
        public struct Gutter: Sendable, Hashable {
            public var text: String
            public var style: TerminalStyle

            public init(
                text: String = "│ ",
                style: TerminalStyle = .dim
            ) {
                self.text = text
                self.style = style
            }
        }

        public var gutter: Gutter
        public init(gutter: Gutter = .init()) { self.gutter = gutter }
    }

    struct List: Sendable, Hashable {
        public struct Unordered: Sendable, Hashable {
            public var marker: String
            public init(marker: String = "• ") { self.marker = marker }
        }

        public struct Ordered: Sendable, Hashable {
            public var suffix: String
            public init(suffix: String = ". ") { self.suffix = suffix }
        }

        public var markerStyle: TerminalStyle
        public var unordered: Unordered
        public var ordered: Ordered

        public init(
            markerStyle: TerminalStyle = .dim,
            unordered: Unordered = .init(),
            ordered: Ordered = .init()
        ) {
            self.markerStyle = markerStyle
            self.unordered = unordered
            self.ordered = ordered
        }
    }

    struct Group: Sendable {
        public struct Presentation: Sendable, Hashable {
            public var titlePrefix: String?
            public var titleSeparator: String
            public var titleStyle: TerminalStyle
            public var contentIndent: Int
            public var spacing: Int

            public init(
                titlePrefix: String? = nil,
                titleSeparator: String = ": ",
                titleStyle: TerminalStyle = .bold,
                contentIndent: Int = 0,
                spacing: Int = 1
            ) {
                self.titlePrefix = titlePrefix
                self.titleSeparator = titleSeparator
                self.titleStyle = titleStyle
                self.contentIndent = max(0, contentIndent)
                self.spacing = max(0, spacing)
            }
        }

        public struct Roles: Sendable {
            public typealias Resolver = @Sendable (StructuredContent.Role) -> Presentation?

            public var values: [StructuredContent.Role: Presentation]
            public var resolve: Resolver?

            public init(
                values: [StructuredContent.Role: Presentation] = [:],
                resolve: Resolver? = nil
            ) {
                self.values = values
                self.resolve = resolve
            }

            public subscript(_ role: StructuredContent.Role) -> Presentation? {
                get { values[role] }
                set { values[role] = newValue }
            }

            func presentation(for role: StructuredContent.Role?) -> Presentation? {
                guard let role else { return nil }
                return values[role] ?? resolve?(role)
            }
        }

        public var standard: Presentation
        public var roles: Roles

        public init(
            standard: Presentation = .init(),
            roles: Roles = .init()
        ) {
            self.standard = standard
            self.roles = roles
        }
    }
}
