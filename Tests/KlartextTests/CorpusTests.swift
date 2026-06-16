// CorpusTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Drives seam detection over real-shaped sample bodies in Corpus/. These assert
// structural properties — the new content lands in `visible`, the history lands
// in `quoted`, and the two don't bleed across the seam — rather than pinning
// every character, so the fixtures read like real mail and stay maintainable.
// Precise, character-exact behavior is covered by the inline goldens in SeamTests.

import Foundation
import Testing
@testable import Klartext

@Suite("Corpus — seam detection over real-shaped bodies")
struct CorpusTests {

    /// Load a sample body from the copied Corpus resource directory.
    private func load(_ subdirectory: String, _ name: String, _ ext: String) throws -> String {
        let url = try #require(
            Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Corpus/\(subdirectory)"),
            "missing corpus fixture Corpus/\(subdirectory)/\(name).\(ext)"
        )
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - HTML

    @Test("Gmail HTML reply: reply text visible, original quoted")
    func gmailHTML() throws {
        let parsed = Klartext.parse(html: try load("html", "gmail-reply", "html"))
        #expect(parsed.sourceFormat == .html)
        #expect(parsed.visible.contains("this looks solid"))
        #expect(parsed.visible.contains("ship Friday"))
        // The em dash entity decoded, no raw markup leaked.
        #expect(parsed.visible.contains("—"))
        #expect(parsed.visible.contains("<") == false)
        // History — attribution and the original body — is below the seam.
        let quoted = try #require(parsed.quoted)
        #expect(quoted.contains("Jane Okonkwo"))
        #expect(quoted.contains("slide 6"))
        // The reply text did not bleed into the quote.
        #expect(quoted.contains("ship Friday") == false)
    }

    @Test("Outlook OWA reply: divRplyFwdMsg header block quoted, no stray rule")
    func outlookHTML() throws {
        let parsed = Klartext.parse(html: try load("html", "outlook-owa-reply", "html"))
        #expect(parsed.visible.contains("Approved on my end"))
        #expect(parsed.visible.contains("loop in procurement"))
        let quoted = try #require(parsed.quoted)
        #expect(quoted.contains("From: Marcus Lindqvist"))
        #expect(quoted.contains("discounted rate"))
        #expect(parsed.visible.contains("Marcus Lindqvist") == false)
    }

    @Test("Apple Mail reply: blockquote[type=cite] quoted")
    func appleHTML() throws {
        let parsed = Klartext.parse(html: try load("html", "apple-mail-reply", "html"))
        #expect(parsed.visible.contains("revised governance matrix"))
        let quoted = try #require(parsed.quoted)
        #expect(quoted.contains("Priya Nair"))
        #expect(quoted.contains("escalation path"))
        #expect(parsed.visible.contains("escalation path") == false)
    }

    // MARK: - Plain text

    @Test("Gmail plain `>`-quoted reply")
    func gmailPlain() throws {
        let parsed = Klartext.parse(plainText: try load("plaintext", "gmail-quoted", "txt"))
        #expect(parsed.sourceFormat == .plainText)
        #expect(parsed.visible.contains("ship it"))
        #expect(parsed.visible.contains("rename the column"))
        let quoted = try #require(parsed.quoted)
        #expect(quoted.hasPrefix("On Mon, Jun 9, 2026"))
        #expect(quoted.contains("> Attaching the Q3 portfolio draft"))
        #expect(parsed.visible.contains("Attaching the Q3") == false)
    }

    @Test("Outlook plain From:/Sent:/To: header block")
    func outlookPlain() throws {
        let parsed = Klartext.parse(plainText: try load("plaintext", "outlook-header-block", "txt"))
        #expect(parsed.visible.contains("Approved on my end"))
        let quoted = try #require(parsed.quoted)
        #expect(quoted.hasPrefix("From: Marcus Lindqvist"))
        #expect(quoted.contains("discounted rate"))
    }

    @Test("Apple plain Begin-forwarded-message marker")
    func appleForwardedPlain() throws {
        let parsed = Klartext.parse(plainText: try load("plaintext", "apple-forwarded", "txt"))
        #expect(parsed.visible.contains("Sharing this for the file"))
        let quoted = try #require(parsed.quoted)
        #expect(quoted.hasPrefix("Begin forwarded message:"))
        #expect(quoted.contains("99.9% monthly uptime"))
        #expect(parsed.visible.contains("99.9%") == false)
    }
}
