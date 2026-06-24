// ForwardTrailer.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// The other outgoing direction. Where ReplyTrailer synthesizes the "On … wrote:"
// quote onto our reply, this builds the "Begin forwarded message:" block onto a
// forward: a header echoing the original From/Date/Subject/To/Cc, then the body
// reproduced VERBATIM — not `> `-prefixed, the one structural difference from a
// reply. The shape mirrors Apple Mail's forward header, including its date format
// (long date + short time, e.g. "June 9, 2026 at 3:04 PM"), which is a distinct
// recognizable convention from the reply attribution line and not required to
// match it.
//
// As with ReplyTrailer, Klartext works in already-formatted display strings; a
// consumer maps its own message/participant types onto these arguments and
// prepends any cover note itself.

import Foundation

enum ForwardTrailer {

    /// The forwarded-message block: the marker, a blank line, the header (each
    /// line omitted when its field is absent), and — when `body` is non-empty — a
    /// blank line then `body` verbatim. An empty `body` yields just marker +
    /// header.
    static func build(
        body: String,
        sender: String,
        date: Date?,
        subject: String?,
        to: [String],
        cc: [String],
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        var lines = ["Begin forwarded message:", "", "From: \(sender)"]
        if let date {
            lines.append("Date: \(formatted(date, locale: locale, timeZone: timeZone))")
        }
        if let subject, !subject.isEmpty {
            lines.append("Subject: \(subject)")
        }
        if !to.isEmpty {
            lines.append("To: \(to.joined(separator: ", "))")
        }
        if !cc.isEmpty {
            lines.append("Cc: \(cc.joined(separator: ", "))")
        }
        let header = lines.joined(separator: "\n")
        guard !body.isEmpty else { return header }
        return "\(header)\n\n\(body)"
    }

    /// Apple Mail's forward-header stamp: long date + short time, locale- and
    /// zone-aware ("June 9, 2026 at 3:04 PM"). A single formatter so the locale
    /// supplies its own date/time join word rather than us hard-coding "at".
    private static func formatted(_ date: Date, locale: Locale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
