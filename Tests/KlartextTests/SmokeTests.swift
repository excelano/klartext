// SmokeTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Proves the package builds, the public surface is reachable, and the concrete
// data types behave. Parsing behavior proper lives in the dedicated suites
// (HTMLReducerTests, SeamTests); this stays a thin reachability check.

import Testing
@testable import Klartext

@Suite("Klartext smoke")
struct SmokeTests {

    @Test("Public types construct and compare")
    func valueTypes() {
        let body = ParsedBody(visible: "hello", sourceFormat: .plainText)
        #expect(body.visible == "hello")
        #expect(body.quoted == nil)
        #expect(body == ParsedBody(visible: "hello", sourceFormat: .plainText))
    }

    @Test("userFacing excludes truly inline parts")
    func attachmentUserFacing() {
        let logo = Attachment(
            id: "logo", filename: "logo.png", mimeType: "image/png", size: 1024,
            contentID: "logo", disposition: .inline, isTrulyInline: true
        )
        let report = Attachment(
            id: "report", filename: "report.pdf", mimeType: "application/pdf", size: 2048,
            contentID: nil, disposition: .attachment, isTrulyInline: false
        )
        let all = [logo, report]
        #expect(all.userFacing == [report])
        #expect(all.hasUserFacing)
        #expect([logo].hasUserFacing == false)
    }

    @Test("parse of an unquoted body returns it whole as visible")
    func parseUnquoted() {
        let parsed = Klartext.parse(plainText: "just text")
        #expect(parsed.sourceFormat == .plainText)
        #expect(parsed.visible == "just text")
        #expect(parsed.quoted == nil)
    }
}
