// HTMLReducerTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Golden tests for the HTML-to-text reducer (DESIGN.md step 2). These assert
// Klartext's output directly. Where that output deliberately differs from Blick's
// HTMLStripper or Zirbe's HTMLText, the difference is a documented improvement
// (correct entity coverage, real nested-structure handling), noted per test.

import Testing
@testable import Klartext

@Suite("HTML reducer")
struct HTMLReducerTests {

    private func reduce(_ html: String) -> String {
        Klartext.plainText(fromHTML: html)
    }

    @Test("Inline tags are stripped, text preserved")
    func inlineTags() {
        #expect(reduce("<p>Hello <b>bold</b> and <i>italic</i>.</p>") == "Hello bold and italic.")
    }

    @Test("Adjacent inline elements don't gain spurious breaks")
    func adjacentInline() {
        // A DOM walker keeps these on one line; a naive per-tag newline rule wouldn't.
        #expect(reduce("<span>Foo</span><a href=\"#\">bar</a>") == "Foobar")
    }

    @Test("<br> becomes a single newline")
    func lineBreak() {
        #expect(reduce("Line one<br>Line two<br/>Line three") == "Line one\nLine two\nLine three")
    }

    @Test("Block elements separate into paragraphs")
    func blockParagraphs() {
        #expect(reduce("<div>First</div><div>Second</div>") == "First\nSecond")
        #expect(reduce("<p>One</p><p>Two</p>") == "One\nTwo")
    }

    @Test("Nested blocks don't double-break")
    func nestedBlocks() {
        // Zirbe's regex stripper emits a newline per close tag, so the inner+outer
        // </div> would stack blank lines; the DOM walk collapses cleanly.
        #expect(reduce("<div><div>Inner</div></div>After") == "Inner\nAfter")
    }

    @Test("script, style, head, title content is dropped whole")
    func droppedSubtrees() {
        let html = """
        <html><head><title>Subject</title><style>.x{color:red}</style></head>\
        <body><script>alert(1)</script><p>Visible</p></body></html>
        """
        #expect(reduce(html) == "Visible")
    }

    @Test("Named, numeric, and hex entities decode")
    func entities() {
        // SwiftSoup covers the full HTML5 named set plus numeric/hex; neither app's
        // hardcoded table did. &amp; resolves once (not into a tag).
        #expect(reduce("<p>Tom &amp; Jerry &lt;tag&gt; &#39;quote&#39; &#x2014; end</p>")
                == "Tom & Jerry <tag> 'quote' \u{2014} end")
        #expect(reduce("<p>caf&eacute; na&iuml;ve</p>") == "café naïve")
    }

    @Test("Non-breaking space becomes an ordinary space")
    func nonBreakingSpace() {
        #expect(reduce("<p>A&nbsp;&nbsp;B</p>") == "A B")
    }

    @Test("Source whitespace and newlines collapse")
    func whitespaceCollapse() {
        let html = "<p>Lots\n   of\t\twhitespace   here</p>"
        #expect(reduce(html) == "Lots of whitespace here")
    }

    @Test("List items each land on their own line")
    func listItems() {
        #expect(reduce("<ul><li>Alpha</li><li>Beta</li><li>Gamma</li></ul>")
                == "Alpha\nBeta\nGamma")
    }

    @Test("HTML comments contribute nothing")
    func comments() {
        #expect(reduce("<p>Before<!-- hidden note -->After</p>") == "BeforeAfter")
    }

    @Test("Blank-line runs are capped at one empty line")
    func blankLineCap() {
        #expect(reduce("<p>A</p><br><br><br><p>B</p>") == "A\n\nB")
    }

    @Test("Whitespace between block elements reads as a paragraph gap")
    func interBlockWhitespace() {
        // Source newlines between two <div>s survive as one blank line, capped;
        // trailing runs of spaces collapse. (Matches the behavior Zirbe's HTMLText
        // had, so the engine swap there is like-for-like.)
        #expect(reduce("<div>one</div>\n\n\n\n<div>two</div>    trailing   spaces")
                == "one\n\ntwo\ntrailing spaces")
    }

    @Test("Empty and whitespace-only markup reduce to empty")
    func emptyBody() {
        #expect(reduce("") == "")
        #expect(reduce("<div>   </div>\n<p>\t</p>") == "")
    }

    @Test("A blockquote's text is preserved (seam detection comes later)")
    func blockquoteText() {
        // Step 2 only reduces to text; splitting new-vs-quoted is step 3.
        let html = "<p>My reply</p><blockquote>Original message</blockquote>"
        #expect(reduce(html) == "My reply\nOriginal message")
    }
}
