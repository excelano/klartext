// SeamTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Golden tests for seam detection (DESIGN.md step 3): splitting the new message
// (`visible`) from the quoted history (`quoted`), in both plain text and HTML.
// The two cross-gains are asserted explicitly: Blick gains `>`/attribution text
// markers, Zirbe gains the Outlook "From:" header block and HTML containers.

import Testing
@testable import Klartext

@Suite("Seam detection — plain text")
struct TextSeamTests {

    @Test("A `>`-quoted line opens the quote")
    func angleQuote() {
        let body = "My reply.\n\n> original line one\n> original line two"
        let parsed = Klartext.parse(plainText: body)
        #expect(parsed.visible == "My reply.")
        #expect(parsed.quoted == "> original line one\n> original line two")
        #expect(parsed.sourceFormat == .plainText)
    }

    @Test("A single-line `On … wrote:` attribution is the seam")
    func singleLineAttribution() {
        let body = "Sounds good.\n\nOn Jun 9, 2026, at 3:00 PM, John <j@x.com> wrote:\nThe original."
        let parsed = Klartext.parse(plainText: body)
        #expect(parsed.visible == "Sounds good.")
        #expect(parsed.quoted == "On Jun 9, 2026, at 3:00 PM, John <j@x.com> wrote:\nThe original.")
    }

    @Test("A wrapped attribution folds from its `On` line, not the `wrote:` line")
    func multiLineAttribution() {
        let body = "Thanks!\n\nOn Mon, Jun 9, 2026 at 3:00 PM\nJohn Smith <j@x.com> wrote:\nOriginal."
        let parsed = Klartext.parse(plainText: body)
        #expect(parsed.visible == "Thanks!")
        #expect(parsed.quoted == "On Mon, Jun 9, 2026 at 3:00 PM\nJohn Smith <j@x.com> wrote:\nOriginal.")
    }

    @Test("An attribution with no `On` prefix stands alone on its `wrote:` line")
    func bareAttribution() {
        let body = "Reply text.\n\nJohn Smith wrote:\nOriginal."
        let parsed = Klartext.parse(plainText: body)
        #expect(parsed.visible == "Reply text.")
        #expect(parsed.quoted == "John Smith wrote:\nOriginal.")
    }

    @Test("`-----Original Message-----` is the seam")
    func originalMessageMarker() {
        let body = "See below.\n\n-----Original Message-----\nFrom: someone"
        let parsed = Klartext.parse(plainText: body)
        #expect(parsed.visible == "See below.")
        #expect(parsed.quoted == "-----Original Message-----\nFrom: someone")
    }

    @Test("`Begin forwarded message:` is the seam")
    func forwardedMarker() {
        let body = "FYI.\n\nBegin forwarded message:\n\nFrom: someone"
        let parsed = Klartext.parse(plainText: body)
        #expect(parsed.visible == "FYI.")
        #expect(parsed.quoted?.hasPrefix("Begin forwarded message:") == true)
    }

    @Test("`---------- Forwarded message ----------` is the seam (Gmail/Outlook-web)")
    func gmailForwardedMarker() {
        let body = "FYI, see below.\n\n---------- Forwarded message ----------\nFrom: Alice <a@x.com>\nSubject: Q3"
        let parsed = Klartext.parse(plainText: body)
        #expect(parsed.visible == "FYI, see below.")
        #expect(parsed.quoted?.hasPrefix("---------- Forwarded message ----------") == true)
    }

    @Test("A bare Gmail/Outlook-web forward with no cover note leaves visible empty")
    func bareGmailForward() {
        let body = "---------- Forwarded message ----------\nFrom: Alice <a@x.com>\nSubject: Q3\n\nThe actual content."
        let parsed = Klartext.parse(plainText: body)
        #expect(parsed.visible.isEmpty)
        #expect(parsed.quoted?.hasPrefix("---------- Forwarded message ----------") == true)
    }

    @Test("An Outlook From:/Sent:/To: header block is the seam (Zirbe's cross-gain)")
    func outlookHeaderBlock() {
        let body = """
        Here are my notes.

        From: John Smith <j@x.com>
        Sent: Monday, June 9, 2026 3:00 PM
        To: David Anderson <d@y.com>
        Subject: Re: Notes

        Original body.
        """
        let parsed = Klartext.parse(plainText: body)
        #expect(parsed.visible == "Here are my notes.")
        #expect(parsed.quoted?.hasPrefix("From: John Smith") == true)
    }

    @Test("A lone `From:` line with no second label is not a seam")
    func loneFromLineIsNotAHeaderBlock() {
        let body = "From: the desk of the CEO, a quick note about the picnic."
        let parsed = Klartext.parse(plainText: body)
        #expect(parsed.visible == "From: the desk of the CEO, a quick note about the picnic.")
        #expect(parsed.quoted == nil)
    }

    @Test("No marker leaves the whole body visible")
    func noMarker() {
        let body = "Just a plain note with no quoting at all.\nSecond line."
        let parsed = Klartext.parse(plainText: body)
        #expect(parsed.visible == "Just a plain note with no quoting at all.\nSecond line.")
        #expect(parsed.quoted == nil)
    }

    @Test("A bare forward (entirely quoted) yields empty visible")
    func entirelyQuoted() {
        let body = "> only quoted\n> nothing new"
        let parsed = Klartext.parse(plainText: body)
        #expect(parsed.visible == "")
        #expect(parsed.quoted == "> only quoted\n> nothing new")
    }

    @Test("maxScanLines bounds the scan so a late marker is not reached")
    func maxScanLinesBound() {
        let body = "line 1\nline 2\nline 3\n> quoted starts on line 4"
        let bounded = Klartext.parse(plainText: body, options: .init(maxScanLines: 3))
        #expect(bounded.quoted == nil)
        let full = Klartext.parse(plainText: body)
        #expect(full.quoted == "> quoted starts on line 4")
    }

    @Test("CRLF line endings are normalized before scanning")
    func crlfNormalized() {
        let body = "Reply.\r\n\r\n> quoted"
        let parsed = Klartext.parse(plainText: body)
        #expect(parsed.visible == "Reply.")
        #expect(parsed.quoted == "> quoted")
    }
}

@Suite("Seam detection — HTML containers")
struct HTMLSeamTests {

    @Test("Gmail's gmail_quote container is the seam")
    func gmailQuote() {
        let html = """
        <div dir="ltr">My reply text.</div>
        <div class="gmail_quote">
          <div class="gmail_attr">On Mon, Jun 9, 2026, John wrote:</div>
          <blockquote class="gmail_quote">Original message.</blockquote>
        </div>
        """
        let parsed = Klartext.parse(html: html)
        #expect(parsed.visible == "My reply text.")
        #expect(parsed.quoted?.contains("Original message.") == true)
        #expect(parsed.quoted?.contains("On Mon, Jun 9, 2026, John wrote:") == true)
        #expect(parsed.sourceFormat == .html)
    }

    @Test("New Outlook.com's x_-prefixed class is still matched (substring guard)")
    func outlookXPrefixedClass() {
        let html = """
        <div>My reply.</div>
        <div class="x_gmail_quote">Quoted history here.</div>
        """
        let parsed = Klartext.parse(html: html)
        #expect(parsed.visible == "My reply.")
        #expect(parsed.quoted == "Quoted history here.")
    }

    @Test("Outlook's divRplyFwdMsg after an <hr> is the seam, hr leaves no stray rule")
    func outlookDivRplyFwdMsg() {
        let html = """
        <div>Here is my answer.</div>
        <hr>
        <div id="divRplyFwdMsg"><b>From:</b> John<br><b>Sent:</b> Monday</div>
        """
        let parsed = Klartext.parse(html: html)
        #expect(parsed.visible == "Here is my answer.")
        #expect(parsed.quoted?.contains("From: John") == true)
    }

    @Test("Apple Mail's blockquote[type=cite] is the seam")
    func appleMailBlockquote() {
        let html = """
        <div>My reply.</div>
        <br>
        <blockquote type="cite">The original message body.</blockquote>
        """
        let parsed = Klartext.parse(html: html)
        #expect(parsed.visible == "My reply.")
        #expect(parsed.quoted == "The original message body.")
    }

    @Test("A bare HTML forward folds 'Begin forwarded message:' chrome into quoted (empty visible)")
    func htmlBareForwardChrome() {
        // Apple Mail's shape for a forward with no cover note: the marker sits in
        // a div above the cite blockquote. Without folding it, the marker strands
        // as the "new message" and the forwarded content hides behind the fold.
        let html = """
        <div></div>
        <div><br>Begin forwarded message:<br></div>
        <blockquote type="cite"><div><b>From:</b> Alice<br><b>Subject:</b> Hi</div></blockquote>
        <blockquote type="cite"><div>The forwarded content.</div></blockquote>
        """
        let parsed = Klartext.parse(html: html)
        #expect(parsed.visible.isEmpty)
        #expect(parsed.quoted?.contains("Begin forwarded message:") == true)
        #expect(parsed.quoted?.contains("The forwarded content.") == true)
    }

    @Test("A real cover note above an HTML forward stays visible")
    func htmlForwardWithCoverNote() {
        let html = """
        <div>Please review.</div>
        <div>Begin forwarded message:</div>
        <blockquote type="cite"><div>The forwarded content.</div></blockquote>
        """
        let parsed = Klartext.parse(html: html)
        #expect(parsed.visible == "Please review.")
        #expect(parsed.quoted?.contains("Begin forwarded message:") == true)
    }

    @Test("Thunderbird's moz-cite-prefix attribution opens the quote")
    func thunderbirdMozCite() {
        let html = """
        <div>Reply body.</div>
        <div class="moz-cite-prefix">On 6/9/26, John wrote:</div>
        <blockquote type="cite">Original.</blockquote>
        """
        let parsed = Klartext.parse(html: html)
        #expect(parsed.visible == "Reply body.")
        #expect(parsed.quoted?.hasPrefix("On 6/9/26, John wrote:") == true)
        #expect(parsed.quoted?.contains("Original.") == true)
    }

    @Test("Nested quote containers collapse to one body-level split")
    func nestedContainersDedup() {
        // The inner blockquote and outer gmail_quote map to the same top-level
        // block, so the split happens once, at that block.
        let html = """
        <div>Top reply.</div>
        <div class="gmail_quote"><blockquote>inner quoted</blockquote></div>
        """
        let parsed = Klartext.parse(html: html)
        #expect(parsed.visible == "Top reply.")
        #expect(parsed.quoted == "inner quoted")
    }

    @Test("HTML with no container falls back to text markers (Talon mirror)")
    func htmlNoContainerTextFallback() {
        // Top-posted reply with the attribution in a plain <div>, no quote class.
        let html = """
        <div>My top-posted reply.</div>
        <div>On Jun 9, 2026, John &lt;j@x.com&gt; wrote:</div>
        <div>The quoted original.</div>
        """
        let parsed = Klartext.parse(html: html)
        #expect(parsed.visible == "My top-posted reply.")
        #expect(parsed.quoted?.hasPrefix("On Jun 9, 2026, John <j@x.com> wrote:") == true)
        #expect(parsed.sourceFormat == .html)
    }

    @Test("HTML with no quote at all stays entirely visible")
    func htmlNoQuote() {
        let html = "<p>Just a note.</p><p>Nothing quoted.</p>"
        let parsed = Klartext.parse(html: html)
        #expect(parsed.visible == "Just a note.\nNothing quoted.")
        #expect(parsed.quoted == nil)
    }

    @Test("HTML is preferred over plain text when both are supplied")
    func htmlPreferredOverPlain() {
        let parsed = Klartext.parse(
            plainText: "ignored plain text",
            html: "<div>From HTML.</div><blockquote type=\"cite\">quoted</blockquote>"
        )
        #expect(parsed.visible == "From HTML.")
        #expect(parsed.quoted == "quoted")
        #expect(parsed.sourceFormat == .html)
    }
}
