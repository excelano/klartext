// HTMLSeam.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Finds the seam in an HTML body by container, which is more reliable than text
// heuristics: a reply client wraps quoted history in a known element (Gmail's
// `gmail_quote`, Outlook's `divRplyFwdMsg`, Apple Mail's `blockquote[type=cite]`,
// Thunderbird's `moz-cite-prefix`). We locate the earliest such container at the
// body's top level, then render everything before it as `visible` and it plus
// everything after as `quoted`.
//
// SwiftSoup is confined to this file and the reducer; no SwiftSoup type crosses
// into the public API. When no container is found this returns nil and parse()
// falls back to reducing the HTML to text and running the text markers — the
// mirror of Talon's strategy, so top-posted mail with no container still folds.

import Foundation
import SwiftSoup

enum HTMLSeam {

    /// Split `html` at the quoted-history container. Returns nil when no container
    /// marker is present, leaving the text-marker fallback to decide.
    static func split(html: String) -> (visible: String, quoted: String?)? {
        guard let document = try? SwiftSoup.parse(html) else { return nil }
        try? document.select(HTMLReducer.droppedSelector).remove()

        let root: Element = document.body() ?? document
        guard let block = seamBlock(in: document, root: root) else { return nil }

        let nodes = root.getChildNodes()
        guard let index = nodes.firstIndex(where: { $0 === block }) else { return nil }

        let visible = HTMLReducer.renderNodes(Array(nodes[..<index]))
        let quoted = HTMLReducer.renderNodes(Array(nodes[index...]))
        return (visible, quoted.isEmpty ? nil : quoted)
    }

    /// Quote-container selectors, in no priority order — the earliest match in
    /// document order wins, not the highest-reliability selector. Class matches use
    /// substrings (`*=`) because new Outlook.com rewrites class names with an `x_`
    /// prefix (`x_gmail_quote`), so an exact-class match would silently miss them.
    private static let quoteSelectors = [
        "[class*=gmail_quote]",
        "[id*=divRplyFwdMsg]",
        "[class*=moz-cite-prefix]",
        "blockquote[type=cite]",
        "blockquote",
    ]

    /// The body-level element where quoted history begins: the earliest, in
    /// document order, of every quote container's top-level ancestor. Mapping each
    /// match up to its body-level ancestor collapses nested matches (a Gmail
    /// `blockquote` inside a `div.gmail_quote`) onto the same split point.
    private static func seamBlock(in document: Document, root: Element) -> Element? {
        var candidates: [Element] = []
        for selector in quoteSelectors {
            if let found = try? document.select(selector).array() {
                candidates.append(contentsOf: found)
            }
        }
        guard !candidates.isEmpty else { return nil }

        let rootChildren = root.getChildNodes()
        var best: (block: Element, index: Int)?
        for candidate in candidates {
            guard let ancestor = bodyLevelAncestor(of: candidate, root: root),
                  let index = rootChildren.firstIndex(where: { $0 === ancestor }) else { continue }
            if best == nil || index < best!.index {
                best = (ancestor, index)
            }
        }
        return best?.block
    }

    /// Walk up from `element` to the ancestor that is a direct child of `root`
    /// (the body). Returns nil if `element` isn't under `root`.
    private static func bodyLevelAncestor(of element: Element, root: Element) -> Element? {
        var node: Element = element
        while let parent = node.parent() {
            if parent === root { return node }
            guard let parentElement = parent as? Element else { return nil }
            node = parentElement
        }
        return nil
    }
}
