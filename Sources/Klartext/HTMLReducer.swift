// HTMLReducer.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Reduces an HTML mail body to readable plain text. It walks the parsed DOM and
// emits newlines at block and <br> boundaries, because SwiftSoup's own .text()
// flattens every line break into a space. Entity decoding (named, numeric, hex)
// comes from SwiftSoup, which is why this file carries no entity table: that
// duplicated map in both apps is exactly what Klartext retires.
//
// SwiftSoup is confined to this file (and the attachment cid join). No SwiftSoup
// type escapes into the public API, so the parser can be swapped wholesale later.

import Foundation
import SwiftSoup

enum HTMLReducer {

    /// Block-level tags whose boundaries a reader sees as line breaks. Inline tags
    /// (`b`, `i`, `a`, `span`, …) are absent on purpose: they must not introduce
    /// breaks. `<br>` and `<hr>` are handled separately as explicit break tags.
    private static let blockTags: Set<String> = [
        "p", "div", "li", "tr", "h1", "h2", "h3", "h4", "h5", "h6",
        "ul", "ol", "table", "blockquote", "section", "article",
        "header", "footer", "pre", "figure", "figcaption",
        "dl", "dt", "dd", "main", "nav", "aside", "address",
    ]

    /// Whole subtrees that never contribute visible text; dropped before walking.
    /// Internal so the seam splitter can drop the same subtrees before it slices
    /// the DOM into visible and quoted halves.
    static let droppedSelector = "script, style, head, title, noscript"

    static func plainText(fromHTML html: String) -> String {
        guard let document = try? SwiftSoup.parse(html) else {
            return fallback(html)
        }
        try? document.select(droppedSelector).remove()

        let root: Element = document.body() ?? document
        var out = ""
        render(root, into: &out)
        return tidy(out)
    }

    /// Reduce a flat list of sibling nodes (a slice of one parent's children) to
    /// text with the same rules as a full body. The seam splitter renders the
    /// visible and quoted halves through this so both sides read identically to a
    /// standalone reduction.
    static func renderNodes(_ nodes: [Node]) -> String {
        var out = ""
        for node in nodes {
            renderNode(node, into: &out)
        }
        return tidy(out)
    }

    /// Depth-first walk of a node's children.
    private static func render(_ node: Node, into out: inout String) {
        for child in node.getChildNodes() {
            renderNode(child, into: &out)
        }
    }

    /// Render one node: text nodes contribute their (entity-decoded) text with
    /// HTML whitespace collapsed; block elements bracket their content in
    /// newlines; `<br>`/`<hr>` emit a single break; inline elements just recurse.
    /// Comments, data, and other node kinds carry no visible text.
    private static func renderNode(_ child: Node, into out: inout String) {
        if let text = child as? TextNode {
            out += collapseWhitespace(text.getWholeText())
        } else if let element = child as? Element {
            let tag = element.tagName().lowercased()
            switch tag {
            case "br":
                out += "\n"
            case "hr":
                ensureNewline(&out)
            default:
                if blockTags.contains(tag) {
                    ensureNewline(&out)
                    render(element, into: &out)
                    ensureNewline(&out)
                } else {
                    render(element, into: &out)
                }
            }
        }
    }

    /// HTML collapses every run of whitespace (including source newlines) to a
    /// single space. Non-breaking spaces become ordinary spaces so the plain-text
    /// reader doesn't carry U+00A0 runs.
    private static func collapseWhitespace(_ raw: String) -> String {
        let unbroken = raw.replacingOccurrences(of: "\u{00A0}", with: " ")
        return unbroken.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    /// Append a newline only when the buffer isn't already at a line break, so a
    /// block boundary never stacks an empty line of its own.
    private static func ensureNewline(_ out: inout String) {
        if !out.isEmpty && !out.hasSuffix("\n") {
            out += "\n"
        }
    }

    /// Tidy the assembled text: collapse intra-line spaces, strip spaces hugging a
    /// newline, cap blank-line runs so paragraphs stay separated without big gaps,
    /// and trim the ends.
    private static func tidy(_ text: String) -> String {
        var t = text.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "[ \\t]*\\n[ \\t]*", with: "\n", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Last-resort path when SwiftSoup can't parse the markup at all (effectively
    /// never for real mail). Strip tags so we never surface raw HTML; entities are
    /// left as-is since there's no DOM to decode them from.
    private static func fallback(_ html: String) -> String {
        html
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
