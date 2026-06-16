// ReplyTrailerTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Golden tests for the outgoing quote trailer. The expectations mirror Zirbe's
// QuotedTextTests verbatim, so a green run proves the ported logic is identical
// and the Zirbe swap preserves outgoing-reply behavior.

import Testing
import Foundation
@testable import Klartext

@Suite("Reply quote trailer")
struct ReplyTrailerTests {
    private let posix = Locale(identifier: "en_US_POSIX")
    private let gmt = TimeZone(identifier: "GMT")!

    @Test("Attribution line, blank line, then the body with each line prefixed")
    func attributionAndPrefixedBody() {
        let trailer = Klartext.replyQuoteTrailer(
            body: "first\n\nthird",
            from: "David Anderson <david@x.com>",
            date: Date(timeIntervalSince1970: 0),
            locale: posix, timeZone: gmt)
        #expect(trailer == """
        On Jan 1, 1970, at 12:00 AM, David Anderson <david@x.com> wrote:

        > first
        >
        > third
        """)
    }

    @Test("A nil date drops the On-clause")
    func nilDate() {
        let trailer = Klartext.replyQuoteTrailer(
            body: "hi", from: "p@x.com", date: nil, locale: posix, timeZone: gmt)
        #expect(trailer == "p@x.com wrote:\n\n> hi")
    }

    @Test("An empty body yields just the attribution")
    func emptyBody() {
        let trailer = Klartext.replyQuoteTrailer(
            body: "", from: "p@x.com", date: nil, locale: posix, timeZone: gmt)
        #expect(trailer == "p@x.com wrote:")
    }
}
