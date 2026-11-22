// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

#if canImport(UIKit)

import Foundation
import Testing
@testable import KlartextUI

@Suite("Tracking pixels")
struct TrackingPixelTests {

    private func sources(_ html: String) -> [String] {
        let pattern = try! NSRegularExpression(pattern: #"\bsrc="([^"]*)""#)
        return pattern.matches(in: html, range: NSRange(html.startIndex..., in: html)).map {
            String(html[Range($0.range(at: 1), in: html)!])
        }
    }

    private func shown(_ html: String) -> String {
        EmailHTMLView.Coordinator.prepared(html, allowRemoteContent: true)
    }

    @Test("Show Images still leaves out tracking pixels")
    func desktopCases() {
        let html = #"""
        <img src="https://x.test/logo.png" width="120" height="40">
        <img src="https://x.test/photo.jpg">
        <img src="https://x.test/open.gif" width="1" height="1">
        <img src="https://x.test/beacon.gif" style="width: 1px; height: 1px">
        <img src="https://x.test/hidden.gif" style="display:none">
        <img src="https://x.test/pixel.gif" width="5" height="5">
        """#
        #expect(sources(shown(html)) == ["https://x.test/logo.png", "https://x.test/photo.jpg"])
    }

    @Test("Each style rule marks a pixel", arguments: [
        "width:0", "height: 1px", "max-width:1px", "MAX-HEIGHT: 0PX", "visibility: hidden", "color:red; display: none",
    ])
    func styleRules(style: String) {
        #expect(sources(shown(#"<img src="https://x.test/a.gif" style="\#(style)">"#)).isEmpty)
    }

    @Test("Images larger than the limit load", arguments: [
        #"width="5" height="6""#, #"width="1""#, #"width="100%" height="1""#, #"style="width:2px; height:2px""#,
    ])
    func notPixels(attributes: String) {
        let html = #"<img src="https://x.test/a.gif" \#(attributes)>"#
        #expect(shown(html) == EmailHTMLView.Coordinator.prepared(html, allowRemoteContent: false))
    }

    @Test("The element stays and only its remote sources go")
    func keepsElement() {
        let html = #"<p><img alt="o" src="https://x.test/o.gif" srcset="https://x.test/o2.gif 2x" width="1" height="1" class="t"></p>"#
        let result = shown(html)
        #expect(result.contains(#"<img alt="o"   width="1" height="1" class="t">"#))
        #expect(!result.contains("x.test"))
    }

    @Test("data: and cid: images are never touched")
    func localSources() {
        let html = #"<img src="cid:logo@x" width="1" height="1"><img src="data:image/gif;base64,R0lGOD" style="display:none">"#
        #expect(sources(shown(html)) == ["cid:logo@x", "data:image/gif;base64,R0lGOD"])
    }

    @Test("A repeated address alone is not a pixel")
    func repeatedAddress() {
        let html = String(repeating: #"<img src="https://x.test/icon.png" width="16" height="16">"#, count: 3)
        #expect(sources(shown(html)).count == 3)
    }

    @Test("Unquoted, single-quoted and upper-case markup is read")
    func markupVariants() {
        let html = #"<IMG SRC=https://x.test/a.gif WIDTH=1 HEIGHT=1><img title='a > b' src='https://x.test/b.gif' style='display:none'>"#
        let result = shown(html)
        #expect(!result.contains("x.test"))
        #expect(result.contains("title='a > b'"))
    }

    @Test("Without remote content the document is left alone")
    func remoteBlocked() {
        let html = #"<img src="https://x.test/open.gif" width="1" height="1">"#
        #expect(sources(EmailHTMLView.Coordinator.prepared(html, allowRemoteContent: false)) == ["https://x.test/open.gif"])
    }
}

#endif
