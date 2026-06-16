// SignatureTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Golden tests for signature separation (DESIGN.md step 4): splitting a trailing
// signature off the new message into ParsedBody.signature, on the conventional
// low-false-positive markers only.

import Testing
@testable import Klartext

@Suite("Signature separation")
struct SignatureTests {

    @Test("The RFC 3676 `-- ` delimiter separates the signature")
    func dashDashSpaceDelimiter() {
        let body = "Let's meet Thursday.\n\n-- \nDavid Anderson\nExcelano"
        let parsed = Klartext.parse(plainText: body)
        #expect(parsed.visible == "Let's meet Thursday.")
        #expect(parsed.signature == "David Anderson\nExcelano")
    }

    @Test("A bare `--` (trailing space stripped in transit) still separates")
    func dashDashStripped() {
        let body = "Approved.\n--\nSent by David"
        let parsed = Klartext.parse(plainText: body)
        #expect(parsed.visible == "Approved.")
        #expect(parsed.signature == "Sent by David")
    }

    @Test("A mobile signature is separated")
    func mobileSignature() {
        let body = "On my way.\n\nSent from my iPhone"
        let parsed = Klartext.parse(plainText: body)
        #expect(parsed.visible == "On my way.")
        #expect(parsed.signature == "Sent from my iPhone")
    }

    @Test("An auto-appended Outlook footer is separated")
    func outlookFooter() {
        let body = "Will do.\n\nGet Outlook for iOS"
        let parsed = Klartext.parse(plainText: body)
        #expect(parsed.visible == "Will do.")
        #expect(parsed.signature == "Get Outlook for iOS")
    }

    @Test("separateSignature off leaves the signature in visible")
    func separationDisabled() {
        let body = "Let's meet Thursday.\n\n-- \nDavid Anderson"
        let parsed = Klartext.parse(plainText: body, options: .init(separateSignature: false))
        #expect(parsed.signature == nil)
        #expect(parsed.visible == "Let's meet Thursday.\n\n-- \nDavid Anderson")
    }

    @Test("No delimiter leaves the body whole with no signature")
    func noSignature() {
        let body = "Just a note, no sign-off here."
        let parsed = Klartext.parse(plainText: body)
        #expect(parsed.visible == "Just a note, no sign-off here.")
        #expect(parsed.signature == nil)
    }

    @Test("A line of dashes that isn't the delimiter is not a signature")
    func dashRuleIsNotADelimiter() {
        // Four-plus dashes is a horizontal rule, not the two-dash delimiter.
        let body = "Section one.\n----\nSection two."
        let parsed = Klartext.parse(plainText: body)
        #expect(parsed.signature == nil)
        #expect(parsed.visible == "Section one.\n----\nSection two.")
    }

    @Test("Seam, signature, and body all separate in one parse")
    func seamAndSignatureTogether() {
        let body = """
        Thanks, that works for me.

        --
        David

        On Jun 9, 2026, John <j@x.com> wrote:
        Can you make Thursday?
        """
        let parsed = Klartext.parse(plainText: body)
        #expect(parsed.visible == "Thanks, that works for me.")
        #expect(parsed.signature == "David")
        #expect(parsed.quoted?.hasPrefix("On Jun 9, 2026") == true)
    }
}
