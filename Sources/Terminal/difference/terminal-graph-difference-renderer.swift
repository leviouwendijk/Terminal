import Difference

public extension TerminalDifferenceRenderer {
    /// Render the available projections in their native layouts. No semantic
    /// changes are inferred from the presentation or its summary.
    static func render(
        _ presentation: DifferencePresentation,
        options: TerminalDifferenceRenderOptions = .init()
    ) -> String {
        let sections = [
            presentation.tree.map { render($0, options: options) } ?? "",
            presentation.graph.map { render($0, options: options) } ?? "",
            presentation.text.map { render($0, options: options) } ?? "",
        ]
        return sections.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    /// A review-oriented graph diff: stable identities, directed endpoints,
    /// and complete before/after values. Unchanged entries follow the same
    /// visibility option as text differences.
    static func render(
        _ layout: GraphDifferenceLayout,
        options: TerminalDifferenceRenderOptions = .init()
    ) -> String {
        guard !layout.nodes.isEmpty || !layout.edges.isEmpty else {
            return ""
        }

        let nodes = layout.nodes.filter {
            options.base.showUnchangedLines || $0.change != .unchanged
        }
        let edges = layout.edges.filter {
            options.base.showUnchangedLines || $0.change != .unchanged
        }

        guard !nodes.isEmpty || !edges.isEmpty else {
            return graphRow("Graph: no changes", style: options.style.separator, options: options)
        }

        var sections: [String] = []
        if !nodes.isEmpty {
            var lines = [graphRow("Nodes", style: options.style.header, options: options)]
            for node in nodes {
                let current = node.after ?? node.before
                let label = current?.label ?? ""
                let headline = "  \(graphMarker(node.change)) [\(node.id)]  \(label)"
                lines.append(graphRow(headline, style: graphStyle(node.change, options: options), options: options))

                switch node.change {
                case .unchanged:
                    if let detail = current?.detail {
                        lines.append(graphRow("      detail  \(detail)", style: options.style.equal, options: options))
                    }
                case .added:
                    if let detail = node.after?.detail {
                        lines.append(graphRow("      detail  \(detail)", style: options.style.insert, options: options))
                    }
                case .removed:
                    if let detail = node.before?.detail {
                        lines.append(graphRow("      detail  \(detail)", style: options.style.delete, options: options))
                    }
                case .modified:
                    if let before = node.before {
                        lines.append(graphRow("      before  \(graphPresentation(before))", style: options.style.delete, options: options))
                    }
                    if let after = node.after {
                        lines.append(graphRow("      after   \(graphPresentation(after))", style: options.style.insert, options: options))
                    }
                }
            }
            sections.append(lines.joined(separator: "\n"))
        }

        if !edges.isEmpty {
            var lines = [graphRow("Edges", style: options.style.header, options: options)]
            for edge in edges {
                let label = (edge.after ?? edge.before)?.presentation.label ?? ""
                let headline = "  \(graphMarker(edge.change)) [\(edge.id)]  \(label)"
                lines.append(graphRow(headline, style: graphStyle(edge.change, options: options), options: options))

                switch edge.change {
                case .unchanged:
                    if let state = edge.after ?? edge.before {
                        lines.append(graphRow("      route   \(graphEdgeState(state))", style: options.style.equal, options: options))
                    }
                case .added:
                    if let state = edge.after {
                        lines.append(graphRow("      after   \(graphEdgeState(state))", style: options.style.insert, options: options))
                    }
                case .removed:
                    if let state = edge.before {
                        lines.append(graphRow("      before  \(graphEdgeState(state))", style: options.style.delete, options: options))
                    }
                case .modified:
                    if let before = edge.before {
                        lines.append(graphRow("      before  \(graphEdgeState(before))", style: options.style.delete, options: options))
                    }
                    if let after = edge.after {
                        lines.append(graphRow("      after   \(graphEdgeState(after))", style: options.style.insert, options: options))
                    }
                }
            }
            sections.append(lines.joined(separator: "\n"))
        }

        return sections.joined(separator: "\n\n")
    }
}

private extension TerminalDifferenceRenderer {
    static func graphMarker(_ change: GraphChangeKind) -> String {
        switch change {
        case .unchanged: " "
        case .added: "+"
        case .removed: "-"
        case .modified: "~"
        }
    }

    static func graphStyle(
        _ change: GraphChangeKind,
        options: TerminalDifferenceRenderOptions
    ) -> TerminalStyle {
        switch change {
        case .unchanged: options.style.equal
        case .added: options.style.insert
        case .removed: options.style.delete
        case .modified: options.style.modified
        }
    }

    static func graphPresentation(_ value: GraphDifferenceLayout.Presentation) -> String {
        guard let detail = value.detail, !detail.isEmpty else {
            return value.label
        }
        return "\(value.label)  ·  \(detail)"
    }

    static func graphEdgeState(_ state: GraphDifferenceLayout.Edge.State) -> String {
        "\(state.endpoints.source) ──▶ \(state.endpoints.destination)  \(graphPresentation(state.presentation))"
    }

    /// Graph names and policy descriptions may originate outside the terminal.
    /// Escape control and bidi-direction characters before applying ANSI style.
    static func graphRow(
        _ content: String,
        style: TerminalStyle,
        options: TerminalDifferenceRenderOptions
    ) -> String {
        let safe = graphSafeText(content)
        guard let columns = options.constrainedColumns else {
            return style.apply(safe)
        }
        return TerminalTextLayout(text: safe, columns: columns)
            .rows.map { style.apply($0.content) }
            .joined(separator: "\n")
    }

    static func graphSafeText(_ text: String) -> String {
        var output = ""
        for scalar in text.unicodeScalars {
            let code = scalar.value
            if code < 0x20 || (0x7F...0x9F).contains(code)
                || (0x202A...0x202E).contains(code)
                || (0x2066...0x2069).contains(code)
            {
                output += "\\u{\(String(code, radix: 16, uppercase: true))}"
            } else {
                output.append(String(scalar))
            }
        }
        return output
    }
}
