# Klartext

A Swift package for displaying already-fetched email faithfully. It ships two
libraries:

- **Klartext** — turns a raw email body into clean, display-ready pieces: HTML
  reduced to readable text, the new message separated from quoted history,
  signatures split out, and attachments classified. Cross-platform, pure
  string and DOM work, no UI.
- **KlartextUI** — iOS-only drop-in SwiftUI views that render a parsed body the
  way the sender intended: `EmailHTMLView` (a faithful WKWebView render, force
  light, remote content gated off by default, `cid:` inline images served on
  device) and `EmailTextView` (a native fold of visible text, quoted history,
  and signature). Depends on Klartext; built on top of it.

Both are shared by two apps with deliberately different feels — **Blick** (a
Microsoft 365 companion) and **Zirbe** (a Messages-style email client) — and are
the common floor of email display they both stand on.

## The one rule

**Klartext handles email content and display. It never fetches email.** Transport
(Microsoft Graph, IMAP/MIME), authentication, and threading stay in each app. The
app fetches a message and hands the toolkit structured values; the toolkit returns
clean pieces (Klartext) and drop-in views (KlartextUI). The package opens no socket
and touches no token. KlartextUI's render blocks remote content by default — loading
it is the consuming app's explicit opt-in — while `cid:` inline images are painted
from on-device bytes, introducing no new external destination.

## Public API

Parsing, from `import Klartext`:

```swift
let parsed = Klartext.parse(plainText: text, html: html, attachments: parts)
parsed.visible        // the new content
parsed.quoted         // history below the seam, if any
parsed.signature      // separated signature, if any
parsed.attachments    // resolved, with accurate inline classification
parsed.preview()      // an aggressively cleaned single-glance gist

Klartext.plainText(fromHTML:)   // HTML → readable text
Klartext.replyQuoteTrailer(...) // "On <date>, <sender> wrote:" + quoted lines
```

Rendering, from `import KlartextUI` (re-exports Klartext, so this is the only
import a view needs):

```swift
// Fill EmailContent from your own transport, then drop in a view.
let content = EmailContent(html: html, plainText: text, parts: parts)

EmailHTMLView(content: content, allowRemoteContent: false) // faithful web render
EmailTextView(content: content)                            // native fold
```

## Design

The full design, vocabulary, marker tables, and migration map live in
[`DESIGN.md`](DESIGN.md).

## Dependency and privacy

One third-party dependency: [SwiftSoup](https://github.com/scinfu/SwiftSoup)
(MIT), used only for HTML parsing and fully encapsulated — no SwiftSoup type
crosses the public API, so a consumer never imports it. KlartextUI additionally
uses WebKit and SwiftUI, both system frameworks, no third party. There is no
network, telemetry, or off-device logging anywhere in the package; the only
network a consumer can trigger is KlartextUI loading remote images, and only
after explicitly opting in with `allowRemoteContent`.

## Requirements

Klartext (parsing) is cross-platform and runs anywhere Swift does. KlartextUI
(rendering) is iOS 17+. Add via Swift Package Manager and pin to a tagged
release; import `Klartext` for parsing only, or `KlartextUI` for the views.

## License

MIT. See [`LICENSE`](LICENSE).
