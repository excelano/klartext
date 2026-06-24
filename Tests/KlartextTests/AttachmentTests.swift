// AttachmentTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Golden tests for the attachment cid join (DESIGN.md step 5). The load-bearing
// rule: a part is truly inline only when its Content-ID is referenced by a `cid:`
// URL in the HTML, regardless of its disposition header. That is what makes the
// paperclip (hasUserFacing) accurate where Graph's hasAttachments lies.

import Testing
@testable import Klartext

@Suite("Attachment classification")
struct AttachmentTests {

    private func input(
        _ filename: String?, _ mime: String, cid: String?, _ disposition: Disposition
    ) -> RawAttachmentInput {
        RawAttachmentInput(filename: filename, mimeType: mime, size: nil,
                           contentID: cid, disposition: disposition)
    }

    @Test("A part referenced by cid: in the HTML is truly inline and not user-facing")
    func referencedInlineIsHidden() {
        let html = #"<p>See chart:</p><img src="cid:chart@x">"#
        let logo = input("chart.png", "image/png", cid: "chart@x", .inline)
        let parsed = Klartext.parse(html: html, attachments: [logo])
        #expect(parsed.attachments.first?.isTrulyInline == true)
        #expect(parsed.attachments.hasUserFacing == false)
        #expect(parsed.attachments.userFacing.isEmpty)
    }

    @Test("An `inline` part nobody references is a real attachment (the rule)")
    func unreferencedInlineIsUserFacing() {
        // Disposition says inline, but no cid: points at it — so it's user-facing.
        let html = #"<p>No images here.</p>"#
        let orphan = input("logo.png", "image/png", cid: "logo@x", .inline)
        let parsed = Klartext.parse(html: html, attachments: [orphan])
        #expect(parsed.attachments.first?.isTrulyInline == false)
        #expect(parsed.attachments.hasUserFacing)
        #expect(parsed.attachments.userFacing.count == 1)
    }

    @Test("A part with no Content-ID is never inline")
    func noContentID() {
        let html = #"<img src="cid:something@x">"#
        let report = input("report.pdf", "application/pdf", cid: nil, .attachment)
        let parsed = Klartext.parse(html: html, attachments: [report])
        #expect(parsed.attachments.first?.isTrulyInline == false)
        #expect(parsed.attachments.hasUserFacing)
    }

    @Test("Angle-bracketed Content-IDs match the bare cid: token")
    func angleBracketNormalization() {
        let html = #"<img src="cid:image001@01D8">"#
        let part = input("image001.png", "image/png", cid: "<image001@01D8>", .inline)
        let parsed = Klartext.parse(html: html, attachments: [part])
        #expect(parsed.attachments.first?.isTrulyInline == true)
    }

    @Test("cid: in an inline style url() also counts as a reference")
    func styleURLReference() {
        let html = #"<div style="background:url(cid:bg@x)">hello</div>"#
        let bg = input("bg.png", "image/png", cid: "bg@x", .inline)
        let parsed = Klartext.parse(html: html, attachments: [bg])
        #expect(parsed.attachments.first?.isTrulyInline == true)
    }

    @Test("A plain-text-only message references nothing, so all parts are user-facing")
    func plainTextNoInline() {
        let part = input("photo.jpg", "image/jpeg", cid: "photo@x", .inline)
        let parsed = Klartext.parse(plainText: "no html here", attachments: [part])
        #expect(parsed.attachments.first?.isTrulyInline == false)
        #expect(parsed.attachments.hasUserFacing)
    }

    @Test("A missing Content-ID gets a stable synthesized id")
    func synthesizedID() {
        let part = input("doc.pdf", "application/pdf", cid: nil, .attachment)
        let parsed = Klartext.parse(plainText: "body", attachments: [part])
        #expect(parsed.attachments.first?.id == "klartext-attachment-0")
    }

    @Test("A mixed set splits into the referenced logo and the real attachment")
    func mixedSet() {
        let html = #"<p>Quarterly numbers attached.</p><img src="cid:siglogo@x">"#
        let logo = input("siglogo.png", "image/png", cid: "siglogo@x", .inline)
        let report = input("Q3.xlsx",
                           "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                           cid: nil, .attachment)
        let parsed = Klartext.parse(html: html, attachments: [logo, report])
        #expect(parsed.attachments.count == 2)
        #expect(parsed.attachments.userFacing.map(\.filename) == ["Q3.xlsx"])
        #expect(parsed.attachments.hasUserFacing)
    }

    // The transport-facing entry points a consumer uses to decide which inline
    // parts to fetch before downloading any bytes. They share the cid join's
    // matching rule, so a part membership test here must agree with classify().

    @Test("referencedContentIDs collects every cid: token, normalized")
    func referencedContentIDsPublicAPI() {
        let html = #"""
        <p>See chart:</p><img src="cid:Chart@X">
        <div style="background:url(cid:bg@x)">hi</div>
        """#
        #expect(Klartext.referencedContentIDs(inHTML: html) == ["chart@x", "bg@x"])
    }

    @Test("normalizeContentID strips the brackets and lowercases for membership")
    func normalizeContentIDPublicAPI() {
        let referenced = Klartext.referencedContentIDs(inHTML: #"<img src="cid:image001@01D8">"#)
        #expect(Klartext.normalizeContentID("<image001@01D8>") == "image001@01d8")
        #expect(referenced.contains(Klartext.normalizeContentID("<image001@01D8>")))
    }

    @Test("The public API agrees with classify() on the same message")
    func publicAPIAgreesWithClassify() {
        let html = #"<p>x</p><img src="cid:logo@x">"#
        let logo = input("logo.png", "image/png", cid: "<logo@x>", .inline)
        // What classify() decides is inline...
        let classified = Klartext.parse(html: html, attachments: [logo]).attachments.first
        // ...must match what the transport-facing pair would pre-select.
        let referenced = Klartext.referencedContentIDs(inHTML: html)
        let preSelected = referenced.contains(Klartext.normalizeContentID("<logo@x>"))
        #expect(classified?.isTrulyInline == preSelected)
        #expect(preSelected)
    }
}

// The pure image predicate a consumer uses for non-email transports (a Teams
// chat attachment that never becomes an EmailContent), so the canonical image
// extension set lives here once instead of drifting in each app.
@Suite("Image classification")
struct ImageClassificationTests {

    @Test("An image/* MIME type is an image regardless of filename")
    func mimePrefixWins() {
        #expect(Klartext.isImageAttachment(mimeType: "image/png", filename: nil))
        #expect(Klartext.isImageAttachment(mimeType: "image/jpeg", filename: "noextension"))
        #expect(Klartext.isImageAttachment(mimeType: "image/heic", filename: "weird.dat"))
    }

    @Test("The MIME prefix test is case- and whitespace-insensitive")
    func mimePrefixNormalized() {
        #expect(Klartext.isImageAttachment(mimeType: "IMAGE/PNG", filename: nil))
        #expect(Klartext.isImageAttachment(mimeType: "  image/gif  ", filename: nil))
    }

    @Test("A generic or absent MIME type falls back to the filename extension")
    func extensionFallback() {
        // Exactly the chat case: transport reports octet-stream, name carries it.
        #expect(Klartext.isImageAttachment(mimeType: "application/octet-stream", filename: "photo.png"))
        #expect(Klartext.isImageAttachment(mimeType: nil, filename: "scan.HEIC"))
    }

    @Test("Both .tif and .tiff are recognized (the drift bug this prevents)")
    func tifAndTiff() {
        #expect(Klartext.isImageAttachment(mimeType: nil, filename: "fax.tif"))
        #expect(Klartext.isImageAttachment(mimeType: nil, filename: "fax.tiff"))
    }

    @Test("A non-image part is not an image by MIME or by extension")
    func notAnImage() {
        #expect(!Klartext.isImageAttachment(mimeType: "application/pdf", filename: "report.pdf"))
        #expect(!Klartext.isImageAttachment(mimeType: "text/calendar", filename: "invite.ics"))
        #expect(!Klartext.isImageAttachment(mimeType: nil, filename: "archive.zip"))
    }

    @Test("Both arguments nil, or a name with no extension, is not an image")
    func emptyInputs() {
        #expect(!Klartext.isImageAttachment(mimeType: nil, filename: nil))
        #expect(!Klartext.isImageAttachment(mimeType: nil, filename: "README"))
        #expect(!Klartext.isImageAttachment(mimeType: nil, filename: ""))
    }
}
