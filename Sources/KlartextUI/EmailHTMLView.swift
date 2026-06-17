// EmailHTMLView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Renders an email's HTML faithfully — the sender's own design — in a sandboxed
// web view. This is the rich path; `EmailTextView` is the compact one.
//
// Three things make it safe and correct by default:
//   • Remote content is blocked until the reader opts in (a remote image is a
//     tracking pixel until proven otherwise). Only `http(s)` subresources are
//     gated; the HTML markup itself is loaded locally with no base URL.
//   • `cid:` inline images are served from the message's own parts on device, so
//     embedded logos and screenshots render without any network access. They are
//     not http(s), so the remote block never touches them (see CIDSchemeHandler).
//   • The canvas is forced light. Email HTML is authored for a white background;
//     senders set dark text and rarely supply a background, so a dark-mode tray
//     would render plain mail dark-on-dark. We render the way Apple Mail does.
//
// A tapped link is handed to the system browser rather than navigating inside
// this view, so links keep working even while images are blocked.
//
// View identity: the cid scheme handler is bound to the web view's configuration
// at creation, which cannot be re-registered. Callers showing a different message
// in the same place must give this view a stable `.id(messageIdentifier)` so
// SwiftUI rebuilds it (a fresh configuration + handler) when the message changes.

#if canImport(UIKit)

import SwiftUI
import UIKit
import WebKit

public struct EmailHTMLView: UIViewRepresentable {
    private let content: EmailContent
    private let allowRemoteContent: Bool

    public init(content: EmailContent, allowRemoteContent: Bool = false) {
        self.content = content
        self.allowRemoteContent = allowRemoteContent
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public func makeUIView(context: Context) -> WKWebView {
        // The cid handler must be registered on the configuration before the web
        // view is created, and the configuration cannot be reused. Build both
        // fresh here and retain the handler on the coordinator for the view's life.
        let configuration = WKWebViewConfiguration()
        let cidHandler = CIDSchemeHandler(parts: content.parts)
        configuration.setURLSchemeHandler(cidHandler, forURLScheme: "cid")
        context.coordinator.cidHandler = cidHandler

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        // Force light: opaque white canvas in a forced-light context so plain
        // text-as-HTML can't come out dark-on-dark and a sender's own dark Web
        // View backdrop never shows through. The document declares
        // color-scheme: light too (see prepared()).
        webView.isOpaque = true
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white
        webView.overrideUserInterfaceStyle = .light
        return webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.render(
            html: documentHTML,
            allowRemoteContent: allowRemoteContent,
            in: webView
        )
    }

    /// The HTML to render: the message's own HTML when present, otherwise its
    /// plain text wrapped in a minimal document so the rich view never shows blank
    /// for a text-only message. (`EmailTextView` is the better choice there.)
    private var documentHTML: String {
        if let html = content.html, !html.isEmpty { return html }
        let text = content.plainText ?? ""
        return #"<pre style="white-space:pre-wrap;word-wrap:break-word;font:-apple-system-body;">"#
            + Self.escape(text) + "</pre>"
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Tracks the last render so an unrelated SwiftUI update doesn't reload the
    /// page (and lose the reader's scroll position) when nothing it cares about
    /// changed. Only a new body or a flip of the remote-content gate reloads.
    /// Also the navigation delegate, routing tapped links out to the browser.
    public final class Coordinator: NSObject, WKNavigationDelegate {
        /// Retains the cid handler for the web view's lifetime. The configuration
        /// holds it weakly enough that losing this reference silently breaks
        /// inline images.
        var cidHandler: CIDSchemeHandler?

        private var lastHTML: String?
        private var lastAllowRemote: Bool?

        /// The rule that blocks every remote load. Local `loadHTMLString` content
        /// has no scheme and is unaffected; `cid:` is not http(s) so it is also
        /// unaffected; only `http(s)` subresources match.
        private static let blockRemoteRuleList = """
        [{"trigger":{"url-filter":"^https?://"},"action":{"type":"block"}}]
        """

        func render(html: String, allowRemoteContent: Bool, in webView: WKWebView) {
            guard lastHTML != html || lastAllowRemote != allowRemoteContent else { return }
            lastHTML = html
            lastAllowRemote = allowRemoteContent

            let document = Self.prepared(html)
            let controller = webView.configuration.userContentController
            controller.removeAllContentRuleLists()

            if allowRemoteContent {
                webView.loadHTMLString(document, baseURL: nil)
            } else {
                WKContentRuleListStore.default().compileContentRuleList(
                    forIdentifier: "klartext-block-remote",
                    encodedContentRuleList: Self.blockRemoteRuleList
                ) { ruleList, _ in
                    if let ruleList { controller.add(ruleList) }
                    // Load whether or not compilation succeeded: failing closed
                    // would show a blank page, so on the rare compile error we
                    // render the mail rather than nothing.
                    webView.loadHTMLString(document, baseURL: nil)
                }
            }
        }

        /// Email HTML often omits a mobile viewport, so WKWebView lays it out at a
        /// desktop width and it shows zoomed out and overflowing. Inject a
        /// device-width viewport (only when the mail doesn't set its own, so
        /// responsive emails keep theirs) plus a little CSS so wide images shrink
        /// to fit rather than spilling past the edge.
        static func prepared(_ html: String) -> String {
            let hasViewport = html.range(
                of: "name=[\"']?viewport", options: [.regularExpression, .caseInsensitive]
            ) != nil
            let head = (hasViewport ? "" : #"<meta name="viewport" content="width=device-width, initial-scale=1">"#)
                // Render light: declare the page light-only so WebKit won't auto-
                // darken it and the sender's own prefers-color-scheme:dark rules stay
                // dormant, and default the canvas to white so a mail that sets text
                // color but no background reads as dark-on-white, not dark-on-dark. A
                // mail that supplies its own background still wins (no !important).
                + #"<meta name="color-scheme" content="light">"#
                + "<style>img,video{max-width:100%;height:auto;}html,body{background:#fff;}body{margin:0;-webkit-text-size-adjust:100%;}</style>"

            // Slip the head into the document where one belongs, or wrap a bare
            // fragment in a minimal document.
            if let r = html.range(of: "<head[^>]*>", options: [.regularExpression, .caseInsensitive]) {
                return html.replacingCharacters(in: r, with: String(html[r]) + head)
            }
            if let r = html.range(of: "<html[^>]*>", options: [.regularExpression, .caseInsensitive]) {
                return html.replacingCharacters(in: r, with: String(html[r]) + "<head>\(head)</head>")
            }
            return "<!DOCTYPE html><html><head>\(head)</head><body>\(html)</body></html>"
        }

        /// Once the page is laid out, zoom it to fit when its content is wider than
        /// the view. The viewport injection handles emails that simply lacked one,
        /// but a fixed-width layout (a hard-coded wide table, common in order and
        /// newsletter mail) still overflows. Measuring the real content width and
        /// rewriting the viewport to lay out at that width and scale down zooms the
        /// whole page to fit without reflowing or distorting its layout.
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let js = """
            (function() {
              var d = document.documentElement, b = document.body;
              var w = Math.max(d.scrollWidth, d.offsetWidth, b ? b.scrollWidth : 0, b ? b.offsetWidth : 0);
              var vw = window.innerWidth;
              if (w > vw + 1) {
                var m = document.querySelector('meta[name=viewport]');
                if (!m) { m = document.createElement('meta'); m.name = 'viewport'; document.head.appendChild(m); }
                m.setAttribute('content', 'width=' + w + ', initial-scale=' + (vw / w));
              }
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        /// Render the local HTML in place, but send a tapped link out to the
        /// system browser (Safari, Mail for `mailto:`, the dialer for `tel:`)
        /// rather than navigating inside this sandboxed view. The first
        /// `loadHTMLString` is a `.other` navigation and is allowed through.
        public func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                decisionHandler(.cancel)
                UIApplication.shared.open(url)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

#endif
