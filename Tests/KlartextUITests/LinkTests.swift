// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

#if canImport(UIKit)

import Foundation
import Testing
import WebKit
@testable import KlartextUI

@MainActor
@Suite("Link handler")
struct LinkTests {

    private func tap(_ html: String) async throws -> EmailLink? {
        let coordinator = EmailHTMLView.Coordinator()
        var links: [EmailLink] = []
        coordinator.onLink = { links.append($0) }
        let webView = EmailHTMLView.makeWebView(parts: [], coordinator: coordinator)
        coordinator.render(html: html, allowRemoteContent: false, in: webView)

        try await waitUntil {
            try await webView.evaluateJavaScript("document.getElementById('link') !== null", in: nil, contentWorld: .defaultClient) as? Bool == true
        }
        _ = try await webView.callAsyncJavaScript("document.getElementById('link').click()", contentWorld: .defaultClient)
        try await waitUntil { !links.isEmpty }
        return links.first
    }

    private func waitUntil(_ condition: () async throws -> Bool) async throws {
        for _ in 0..<100 {
            if (try? await condition()) == true { return }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    @Test("A tapped link reaches the handler with its visible text")
    func linkText() async throws {
        let link = try await tap(#"<p><a id="link" href="https://example.com/path?utm_source=x">  Visit <b>your</b>\#n  account </a></p>"#)
        #expect(link == EmailLink(url: URL(string: "https://example.com/path?utm_source=x")!, text: "Visit your account"))
    }

    @Test("An image link has empty text")
    func imageLink() async throws {
        let link = try await tap(#"<a id="link" href="https://example.com/"><img src="cid:logo" alt="Logo"></a>"#)
        #expect(link == EmailLink(url: URL(string: "https://example.com/")!, text: ""))
    }

    @Test("The message's own scripts stay off")
    func messageScriptsOff() async throws {
        let html = #"<a id="link" href="https://example.com/">Home</a><script>document.getElementById('link').textContent = 'ran';</script>"#
        let link = try await tap(html)
        #expect(link?.text == "Home")
    }
}

#endif
