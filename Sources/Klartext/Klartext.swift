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
    /// STUB (DESIGN.md step 3): seam detection is not implemented yet. For now it
    /// returns the whole body as `visible` with no quoted split, so callers can
    /// integrate against the shape while the logic lands.
    public static func parse(
        plainText: String? = nil,
        html: String? = nil,
        attachments: [RawAttachmentInput] = [],
        options: Options = .init()
    ) -> ParsedBody {
        if let html {
            return ParsedBody(visible: Self.plainText(fromHTML: html), sourceFormat: .html)
        }
        return ParsedBody(visible: plainText ?? "", sourceFormat: .plainText)
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
