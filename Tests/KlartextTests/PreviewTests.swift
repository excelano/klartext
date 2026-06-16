// PreviewTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Golden tests for ParsedBody.preview() (DESIGN.md step 4): the lossy single-
// glance cleanup over `visible`. Preview-only cuts (valediction, salutation) are
// exercised here and must never affect `visible`/`quoted`, which stay intact.

import Testing
@testable import Klartext

@Suite("Preview glance")
struct PreviewTests {

    private func preview(_ visible: String, maxLength: Int? = nil) -> String {
        ParsedBody(visible: visible, sourceFormat: .plainText).preview(maxLength: maxLength)
    }

    @Test("A salutation on its own line is stripped")
    func leadingSalutation() {
        #expect(preview("Hi David,\nThe deck is ready for review.") == "The deck is ready for review.")
    }

    @Test("A same-line salutation is kept (not a standalone greeting)")
    func sameLineSalutationKept() {
        #expect(preview("Hi David, can you review the deck?") == "Hi David, can you review the deck?")
    }

    @Test("A trailing valediction is cut for the glance")
    func valedictionCut() {
        #expect(preview("The numbers check out.\n\nThanks,\nDavid") == "The numbers check out.")
    }

    @Test("A leftover signature is cut even when it wasn't separated")
    func leftoverSignatureCut() {
        // preview() is the safety net when separateSignature was off.
        #expect(preview("Heading out now.\n\nSent from my iPhone") == "Heading out now.")
    }

    @Test("Image placeholders from HTML-to-text are dropped")
    func imagePlaceholdersDropped() {
        #expect(preview("[Calendar Icon] Your 3pm is confirmed.") == "Your 3pm is confirmed.")
        // Genuine bracketed text survives.
        #expect(preview("[EXTERNAL] Please verify this request.") == "[EXTERNAL] Please verify this request.")
    }

    @Test("maxLength bounds the glance on a word boundary")
    func boundedToWordBoundary() {
        let result = preview("The quarterly portfolio review is scheduled for next Tuesday.", maxLength: 30)
        #expect(result == "The quarterly portfolio")
        #expect(result.count <= 30)
    }

    @Test("A full reply previews down to just the gist")
    func fullReplyGist() {
        let body = """
        Hi Jane,

        Yes, let's ship Friday. I left two notes on slide 6.

        Thanks,
        David

        On Mon, Jun 9, 2026, Jane <jane@x.com> wrote:
        Do we keep the legacy column?
        """
        let parsed = Klartext.parse(plainText: body)
        // The stored fields keep everything; only preview() is lossy. The
        // "Thanks,\nDavid" sign-off is a valediction (preview-only), not a `--`
        // signature, so it stays in visible and signature is nil.
        #expect(parsed.visible == "Hi Jane,\n\nYes, let's ship Friday. I left two notes on slide 6.\n\nThanks,\nDavid")
        #expect(parsed.signature == nil)
        #expect(parsed.quoted?.hasPrefix("On Mon, Jun 9, 2026") == true)
        // The glance strips the salutation and the valediction, leaving the gist.
        #expect(parsed.preview() == "Yes, let's ship Friday. I left two notes on slide 6.")
    }

    @Test("preview() over visible with no cruft returns it unchanged")
    func cleanVisibleUnchanged() {
        #expect(preview("A single clean sentence.") == "A single clean sentence.")
    }
}
