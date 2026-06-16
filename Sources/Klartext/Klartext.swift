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
    /// container still folds. With `Options.separateSignature` on (the default), a
    /// trailing signature is then split off `visible` into `signature`. Attachment
    /// classification is layered on in a later build step.
    public static func parse(
        plainText: String? = nil,
        html: String? = nil,
        attachments: [RawAttachmentInput] = [],
        options: Options = .init()
    ) -> ParsedBody {
        let format: BodyFormat
        let seam: (visible: String, quoted: String?)
        if let html, !html.isEmpty {
            format = .html
            seam = HTMLSeam.split(html: html)
                ?? TextSeam.split(Self.plainText(fromHTML: html), options: options)
        } else {
            format = .plainText
            seam = TextSeam.split(plainText ?? "", options: options)
        }

        let (body, signature) = Signature.separate(seam.visible, options: options)
        return ParsedBody(visible: body, quoted: seam.quoted, signature: signature, sourceFormat: format)
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
    /// salutation, leftover signature, and trailing valediction removed, image
    /// placeholders dropped, optionally bounded to `maxLength` on a word boundary.
    /// Lossy by design — the full `visible` and `quoted` stay available for "show
    /// full message", so a wrong cut here is recoverable.
    func preview(maxLength: Int? = nil) -> String {
        Preview.glance(visible, maxLength: maxLength)
    }
}
