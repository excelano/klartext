// Klartext.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// The public entry points. This file is the API skeleton: the value types are
// real, but the algorithmic bodies are stubs filled in by later build steps
// (HTML reducer, seam detection, signature/preview, attachment cid join). See
// DESIGN.md §9 for the build order.

import Foundation

public enum Klartext {

    /// Parse a raw body into structured pieces. Pass whichever representations are
    /// on hand; HTML is preferred when present because container based quote
    /// detection beats text heuristics.
    ///
    /// Seam detection splits `visible` (the new message) from `quoted` (the history
    /// below it). For HTML it first looks for a quote container; finding none it
    /// reduces to text and runs the text markers, so top posted mail with no
    /// container still folds. Signature separation and attachment classification
    /// are layered on in later build steps.
    public static func parse(
        plainText: String? = nil,
        html: String? = nil,
        attachments: [RawAttachmentInput] = [],
        options: Options = .init()
    ) -> ParsedBody {
        if let html, !html.isEmpty {
            if let split = HTMLSeam.split(html: html) {
                return ParsedBody(visible: split.visible, quoted: split.quoted, sourceFormat: .html)
            }
            let split = TextSeam.split(Self.plainText(fromHTML: html), options: options)
            return ParsedBody(visible: split.visible, quoted: split.quoted, sourceFormat: .html)
        }
        let split = TextSeam.split(plainText ?? "", options: options)
        return ParsedBody(visible: split.visible, quoted: split.quoted, sourceFormat: .plainText)
    }

    /// Reduce HTML to readable plain text: block aware line breaks, entities
    /// decoded. Used internally by `parse()`; exposed for callers that only need
    /// text.
    public static func plainText(fromHTML html: String) -> String {
        HTMLReducer.plainText(fromHTML: html)
    }

    /// Build a conventional reply quote trailer ("On <date>, <sender> wrote:" plus
    /// `>` prefixed lines).
    ///
    /// STUB (DESIGN.md step 3): returns an empty string until implemented.
    public static func replyQuoteTrailer(
        body: String,
        from sender: String,
        date: Date,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        ""
    }
}

public extension ParsedBody {
    /// An aggressively cleaned single glance preview of the new content:
    /// salutation, signature, and trailing valediction removed. Lossy by design.
    ///
    /// STUB (DESIGN.md step 4): returns `visible`, optionally truncated, until the
    /// glance cleanup lands.
    func preview(maxLength: Int? = nil) -> String {
        guard let maxLength, visible.count > maxLength else { return visible }
        return String(visible.prefix(maxLength))
    }
}
