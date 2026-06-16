// ReplyTrailer.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// The outgoing direction: build the conventional quote trailer onto our own
// reply so the people we answer keep their thread context. This is the inverse
// of seam detection (which strips an incoming quote); here we synthesize one in
// the Apple Mail shape — an attribution line, a blank line, then the quoted
// message with every line prefixed `> `.
//
// Klartext takes the sender as an already-formatted display string and works in
// primitives; mapping a consumer's own message/participant type onto these
// arguments stays in the consumer (Zirbe's Message lives in Zirbe).

import Foundation

enum ReplyTrailer {

    /// The trailer for one quoted message: its attribution line, a blank line,
    /// then `body` with every line prefixed `> ` (empty lines become a bare `>`).
    /// An empty `body` yields just the attribution. The body is reproduced
    /// verbatim and is not trimmed.
    static func build(
        body: String,
        sender: String,
        date: Date?,
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        let attribution = attributionLine(sender: sender, date: date, locale: locale, timeZone: timeZone)
        guard !body.isEmpty else { return attribution }
        let quoted = body
            .components(separatedBy: "\n")
            .map { $0.isEmpty ? ">" : "> \($0)" }
            .joined(separator: "\n")
        return "\(attribution)\n\n\(quoted)"
    }

    /// The "On <date>, at <time>, <sender> wrote:" line. The date is dropped when
    /// there is none, leaving "<sender> wrote:".
    private static func attributionLine(
        sender: String,
        date: Date?,
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        guard let date else { return "\(sender) wrote:" }
        let dateText = formatted(date, "MMM d, yyyy", locale: locale, timeZone: timeZone)
        let timeText = formatted(date, "h:mm a", locale: locale, timeZone: timeZone)
        return "On \(dateText), at \(timeText), \(sender) wrote:"
    }

    private static func formatted(_ date: Date, _ format: String, locale: Locale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
