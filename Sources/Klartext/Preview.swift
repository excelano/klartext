// Preview.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// The lossy single-glance cleanup behind ParsedBody.preview(). It runs over
// `visible` — already free of quoted history (the seam) and usually of the
// signature (separateSignature) — and strips what a one-line glance doesn't
// want: a leading salutation on its own line, a trailing valediction or leftover
// signature, image placeholders that HTML-to-text conversion leaves as "[Logo]".
// This is Blick's PreviewCleaner ported in; the quote-marker cuts it used to do
// are gone because seam detection already handled them upstream.
//
// Lossy by design: a wrong cut here is fine because the full `visible`/`quoted`
// stay on ParsedBody for "show full message". preview() never feeds a fold.

import Foundation

enum Preview {

    // Salutation on its own line: an opener, up to ~60 chars of name/team, a comma
    // or bang, then a newline — so "Hi David, please review" on one line stays.
    private static let salutation = try? NSRegularExpression(
        pattern: #"^(hi|hello|hey|dear|greetings|good\s+(morning|afternoon|evening|day))\b[^\n,!]{0,60}[,!]\s*\n"#,
        options: .caseInsensitive)

    // Leftover signature, as a safety net for when separateSignature was off.
    private static let signatureMarker = try? NSRegularExpression(
        pattern: #"\n+(--\s*\n|Sent from my [^\n]{0,30}|Sent from Outlook[^\n]*|Get Outlook for[^\n]*|Sent via [^\n]*)"#,
        options: .caseInsensitive)

    // Valediction on its own line ("Thanks,\n"). Preview-only: requires a comma so
    // a casual mid-paragraph "Thanks!" isn't taken for a sign-off.
    private static let valediction = try? NSRegularExpression(
        pattern: #"\n+(Thanks|Thank you|Regards|Best|Best regards|Kind regards|Cheers|Sincerely|Best wishes|Take care|Warm regards|All the best)\s*,\s*\n"#,
        options: .caseInsensitive)

    // A horizontal-rule line (Outlook fences sections with long underscore runs).
    private static let separatorLine = try? NSRegularExpression(pattern: #"(^|\n+)[_\-=]{4,}"#)

    // Image placeholders an HTML-to-text pass leaves: "[Calendar Icon]", "[cid:…]",
    // "[logo.png]". Only brackets carrying an image marker are dropped, so real
    // bracketed text like "[EXTERNAL]" survives.
    private static let imagePlaceholder = try? NSRegularExpression(
        pattern: #"\[[^\]\n]*(?:cid:|\.(?:png|jpe?g|gif|svg|bmp|webp|tiff?|ico)\b|\b(?:image|images|icon|logo|photo|picture|graphic|graphics|banner|avatar|thumbnail|headshot|spacer|pixel)\b)[^\]\n]*\]"#,
        options: .caseInsensitive)
    private static let emptyBracket = try? NSRegularExpression(pattern: #"\[[ \t]*\]"#)
    private static let horizontalSpace = try? NSRegularExpression(pattern: #"[^\S\n]{2,}"#)
    private static let collapseBlankLines = try? NSRegularExpression(pattern: #"\n([ \t]*\n)+"#)

    /// Clean `visible` to a glance and optionally bound its length.
    static func glance(_ visible: String, maxLength: Int?) -> String {
        var s = visible
        s = replaceAll(imagePlaceholder, in: s, with: "")
        s = replaceAll(emptyBracket, in: s, with: "")
        s = replaceAll(horizontalSpace, in: s, with: " ")
        s = cutAtEarliestMarker(s)
        s = stripLeadingSalutation(s)
        s = replaceAll(collapseBlankLines, in: s, with: "\n")
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return bound(s, to: maxLength)
    }

    /// Cut at the earliest of any leftover signature, valediction, or separator
    /// line; everything from there down is dropped. A position-zero cut is valid
    /// (auto-generated content that opens with a separator) and yields an empty
    /// preview, which is the right call for it.
    private static func cutAtEarliestMarker(_ text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        let locations = [signatureMarker, valediction, separatorLine]
            .compactMap { $0?.firstMatch(in: text, range: range)?.range.location }
        guard let cut = locations.min() else { return text }
        return String(text.prefix(cut))
    }

    private static func stripLeadingSalutation(_ text: String) -> String {
        guard let salutation else { return text }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = salutation.firstMatch(in: text, range: range), match.range.location == 0 else {
            return text
        }
        let end = text.index(text.startIndex, offsetBy: match.range.length)
        return String(text[end...])
    }

    /// Bound to `maxLength` characters, backing up to the last word boundary so the
    /// glance never ends mid-word.
    private static func bound(_ text: String, to maxLength: Int?) -> String {
        guard let maxLength, text.count > maxLength else { return text }
        let cut = text.prefix(maxLength)
        if let lastSpace = cut.lastIndex(where: { $0 == " " || $0 == "\n" }) {
            return String(cut[..<lastSpace]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(cut).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func replaceAll(_ regex: NSRegularExpression?, in text: String, with template: String) -> String {
        guard let regex else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }
}
