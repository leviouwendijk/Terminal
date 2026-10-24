import Difference

/// The projection to render, not a different representation of the source diff.
public enum TerminalDifferenceView: Sendable, Hashable {
    case text
    case tree
    case combined
}

public extension TerminalDifferenceRenderer {
    /// Render a generic structural layout using Difference's canonical tree
    /// render plan for markers and branch geometry.
    static func render(
        _ layout: TreeDifferenceLayout,
        options: TerminalDifferenceRenderOptions = .init()
    ) -> String {
        let plan = TreeDifferenceRenderPlan.make(layout)
        return plan.lines.map { line in
            let change_style = treeStyle(for: line.change, style: options.style)
            return line.segments.map { segment in
                switch segment.component {
                case .marker:
                    return change_style.apply(segment.text) + " "
                case .branch:
                    return options.style.border.apply(segment.text)
                case .label:
                    return change_style.apply(segment.text)
                }
            }.joined()
        }.joined(separator: "\n")
    }

    static func render<Value>(
        _ difference: TreeDifference<Value>,
        options: TerminalDifferenceRenderOptions = .init()
    ) -> String {
        render(
            TreeDifferenceLayout.make(difference),
            options: options
        )
    }

    /// Render one or both computed layouts without flattening the original
    /// semantic Difference or reinterpreting its operation identities.
    static func render<Value>(
        _ difference: Difference<Value>,
        view: TerminalDifferenceView = .combined,
        options: TerminalDifferenceRenderOptions = .init()
    ) -> String {
        switch view {
        case .text:
            return render(
                difference.make_text_layout(options: options.base),
                options: options
            )
        case .tree:
            return render(difference.layout.tree, options: options)
        case .combined:
            let tree = render(difference.layout.tree, options: options)
            let text = render(
                difference.make_text_layout(options: options.base),
                options: options
            )
            return [tree, text]
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")
        }
    }
}

private extension TerminalDifferenceRenderer {
    static func treeStyle(
        for change: TreeChangeKind,
        style: TerminalDifferenceStyle
    ) -> TerminalStyle {
        switch change {
        case .unchanged: return style.equal
        case .added: return style.insert
        case .removed: return style.delete
        case .modified: return style.modified
        case .moved: return style.moved
        case .moved_modified: return style.moved_modified
        }
    }
}
