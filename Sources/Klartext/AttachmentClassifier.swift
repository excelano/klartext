// AttachmentClassifier.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// The cid join: resolve raw transport parts into Attachments with accurate inline
// classification. The load-bearing rule (DESIGN.md §4) is that a part is truly
// inline ONLY when its Content-ID is actually referenced by a `cid:` URL in the
// displayed HTML, no matter what its disposition header claims. An "inline" part
// nobody references is a real attachment; that distinction is what makes Blick's
// paperclip and Zirbe's attachment list correct rather than approximately right.
//
// Content-ID references live in attribute values (`src="cid:…"`, `background`,
// CSS `url(cid:…)`), and the ids are long unique tokens, so a substring scan for
// `cid:` is both sufficient and safe — no DOM needed here, so this stays off
// SwiftSoup.

import Foundation

enum AttachmentClassifier {

    /// Resolve raw parts against the HTML body. With no HTML (a plain-text-only
    /// message) nothing is referenced, so every part is a real attachment.
    static func classify(_ inputs: [RawAttachmentInput], html: String?) -> [Attachment] {
        let referenced = html.map(referencedContentIDs) ?? []
        return inputs.enumerated().map { index, input in
            let isTrulyInline = input.contentID
                .map { referenced.contains(normalize($0)) } ?? false
            return Attachment(
                id: input.contentID ?? "klartext-attachment-\(index)",
                filename: input.filename,
                mimeType: input.mimeType,
                size: input.size,
                contentID: input.contentID,
                disposition: input.disposition,
                isTrulyInline: isTrulyInline
            )
        }
    }

    /// Matches a `cid:` URL and captures the Content-ID token after it, stopping at
    /// the quote, paren, angle bracket, or whitespace that closes the reference.
    private static let cidReference = try? NSRegularExpression(
        pattern: #"cid:([^"'()\s<>]+)"#, options: .caseInsensitive)

    /// The set of Content-IDs the HTML actually references, normalized for
    /// comparison against the parts' own ids.
    private static func referencedContentIDs(_ html: String) -> Set<String> {
        guard let cidReference else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        var found: Set<String> = []
        for match in cidReference.matches(in: html, range: range) {
            guard match.numberOfRanges > 1,
                  let tokenRange = Range(match.range(at: 1), in: html) else { continue }
            found.insert(normalize(String(html[tokenRange])))
        }
        return found
    }

    /// A part's Content-ID arrives wrapped in angle brackets (`<id@host>`) while the
    /// `cid:` URL carries the bare token; lowercasing and stripping the brackets and
    /// surrounding whitespace lets the two compare.
    private static func normalize(_ contentID: String) -> String {
        contentID
            .trimmingCharacters(in: CharacterSet(charactersIn: "<> \t"))
            .lowercased()
    }
}
