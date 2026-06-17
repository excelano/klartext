// CIDSchemeHandler.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Serves `cid:` inline images to a WKWebView from the message's own parts. An
// HTML email references an embedded image as `<img src="cid:logo@example.com">`,
// and the matching part arrives in the fetched message with a Content-ID of
// `<logo@example.com>`. WebKit has no built-in cid handling, so without this the
// image renders blank.
//
// Privacy note: cid bytes are already on device — they came in with the message
// the app fetched — so serving them opens no network connection and defines no
// new external destination. cid images therefore render regardless of the remote
// content gate in EmailHTMLView, which only blocks http(s). This is deliberate.

#if canImport(UIKit)

import Foundation
import WebKit

final class CIDSchemeHandler: NSObject, WKURLSchemeHandler {
    /// Normalized Content-ID → (mime type, bytes). Built once per message.
    private let resources: [String: (mime: String, data: Data)]

    init(parts: [EmailPart]) {
        var map: [String: (String, Data)] = [:]
        for part in parts {
            guard let cid = part.contentID, let data = part.data else { continue }
            map[Self.normalize(cid)] = (part.mimeType, data)
        }
        self.resources = map
    }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else {
            task.didFailWithError(URLError(.badURL))
            return
        }
        // For "cid:logo@example.com" the token is everything after the scheme.
        let raw = url.absoluteString
        let afterScheme = raw.lowercased().hasPrefix("cid:") ? String(raw.dropFirst(4)) : raw
        let token = Self.normalize(afterScheme.removingPercentEncoding ?? afterScheme)

        guard let resource = resources[token] else {
            // Unknown cid: complete the task with a 404 so WebKit shows the
            // broken-image glyph rather than hanging the subresource load.
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            task.didReceive(response)
            task.didFinish()
            return
        }

        let response = URLResponse(
            url: url,
            mimeType: resource.mime,
            expectedContentLength: resource.data.count,
            textEncodingName: nil
        )
        task.didReceive(response)
        task.didReceive(resource.data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {
        // The handler responds synchronously in `start`, so there is never an
        // in-flight task to cancel. Required by the protocol.
    }

    /// Match the Klartext core's cid normalization exactly (strip angle brackets
    /// and whitespace, lowercase) so a part's `<id@host>` resolves the HTML's
    /// bare `cid:id@host`. Deliberately duplicated: the core's copy is private and
    /// has no other consumer worth widening the public surface for.
    static func normalize(_ contentID: String) -> String {
        contentID
            .trimmingCharacters(in: CharacterSet(charactersIn: "<> \t"))
            .lowercased()
    }
}

#endif
