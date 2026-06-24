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
    /// trailing signature is then split off `visible` into `signature`. Raw
    /// attachment parts are resolved against the HTML so each one's inline status
    /// reflects whether the body actually references it.
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
        return ParsedBody(
            visible: body,
            quoted: seam.quoted,
            signature: signature,
            sourceFormat: format,
            attachments: AttachmentClassifier.classify(attachments, html: html)
        )
    }

    /// Reduce HTML to readable plain text: block aware line breaks, entities
    /// decoded. Used internally by `parse()`; exposed for callers that only need
    /// text.
    public static func plainText(fromHTML html: String) -> String {
        HTMLReducer.plainText(fromHTML: html)
    }

    /// Build a conventional reply quote trailer for one quoted message: its
    /// attribution line ("On <date>, at <time>, <sender> wrote:"), a blank line,
    /// then `body` with every line prefixed `> `. Pass `date: nil` to drop the
    /// "On …" clause, leaving "<sender> wrote:". `sender` is the already-formatted
    /// display string; an empty `body` yields just the attribution.
    public static func replyQuoteTrailer(
        body: String,
        from sender: String,
        date: Date?,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        ReplyTrailer.build(body: body, sender: sender, date: date, locale: locale, timeZone: timeZone)
    }

    /// The set of Content-IDs an HTML body references via `cid:` URLs, normalized
    /// (angle brackets and surrounding whitespace stripped, lowercased) so they
    /// compare directly against a MIME part's own `<id@host>` Content-ID. Lets a
    /// transport decide which inline parts to fetch before downloading any bytes,
    /// using the same matching rule the attachment cid join already trusts.
    public static func referencedContentIDs(inHTML html: String) -> Set<String> {
        AttachmentClassifier.referencedContentIDs(html)
    }

    /// Normalize one Content-ID the same way, so a caller holding a part's raw
    /// `<id@host>` can test membership in the set above.
    public static func normalizeContentID(_ contentID: String) -> String {
        AttachmentClassifier.normalize(contentID)
    }

    /// True when an attachment is an image, judged from its MIME type and/or
    /// filename. Pure: performs no I/O and no HTML parse. For callers holding
    /// attachment metadata outside an email (a chat transport whose parts never
    /// become an `EmailContent`) that can't go through `parse()` and would
    /// otherwise hand-roll an extension list that drifts from this one.
    ///
    /// Rule: an `image/*` MIME type wins; otherwise a known image filename
    /// extension. Either argument may be nil.
    public static func isImageAttachment(mimeType: String?, filename: String?) -> Bool {
        AttachmentClassifier.isImage(mimeType: mimeType, filename: filename)
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
