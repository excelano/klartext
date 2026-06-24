// ForwardTrailerTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Golden tests for the outgoing forward block. They mirror Zirbe's current
// forwardBody/forwardHeader output, so a green run proves the ported logic is
// identical and the Zirbe swap preserves outgoing-forward behavior — including
// the Apple Mail date stamp (long date + short time), the one format difference
// from the reply trailer.

import Testing
import Foundation
@testable import Klartext

@Suite("Forward quote trailer")
struct ForwardTrailerTests {
    private let posix = Locale(identifier: "en_US_POSIX")
    private let gmt = TimeZone(identifier: "GMT")!

    // The short-time style stamps a narrow no-break space (U+202F) before AM/PM,
    // exactly as Apple Mail does; the golden literals carry it explicitly so the
    // test pins the real format rather than an ASCII approximation of it.
    @Test("Full header, then the body reproduced verbatim (not quoted)")
    func fullHeaderAndVerbatimBody() {
        let trailer = Klartext.forwardQuoteTrailer(
            body: "first\n\nthird",
            from: "Pat <pat@x.com>",
            date: Date(timeIntervalSince1970: 0),
            subject: "Plan",
            to: ["me@x.com"],
            cc: ["cc@x.com"],
            locale: posix, timeZone: gmt)
        #expect(trailer == """
        Begin forwarded message:

        From: Pat <pat@x.com>
        Date: January 1, 1970 at 12:00\u{202F}AM
        Subject: Plan
        To: me@x.com
        Cc: cc@x.com

        first

        third
        """)
    }

    @Test("Multiple To/Cc recipients are joined with a comma")
    func joinedRecipients() {
        let trailer = Klartext.forwardQuoteTrailer(
            body: "x",
            from: "Pat <pat@x.com>",
            date: nil,
            subject: nil,
            to: ["a@x.com", "b@x.com"],
            cc: ["c@x.com", "d@x.com"],
            locale: posix, timeZone: gmt)
        #expect(trailer == """
        Begin forwarded message:

        From: Pat <pat@x.com>
        To: a@x.com, b@x.com
        Cc: c@x.com, d@x.com

        x
        """)
    }

    @Test("Each absent field omits its header line")
    func omittedLines() {
        let trailer = Klartext.forwardQuoteTrailer(
            body: "body",
            from: "someone",
            date: nil,
            subject: "",
            to: [],
            cc: [],
            locale: posix, timeZone: gmt)
        #expect(trailer == """
        Begin forwarded message:

        From: someone

        body
        """)
    }

    @Test("An empty body yields just the marker and header")
    func emptyBody() {
        let trailer = Klartext.forwardQuoteTrailer(
            body: "",
            from: "Pat <pat@x.com>",
            date: Date(timeIntervalSince1970: 0),
            subject: "Plan",
            to: [],
            cc: [],
            locale: posix, timeZone: gmt)
        #expect(trailer == """
        Begin forwarded message:

        From: Pat <pat@x.com>
        Date: January 1, 1970 at 12:00\u{202F}AM
        Subject: Plan
        """)
    }
}
