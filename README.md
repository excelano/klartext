# Klartext

A small Swift package that turns an already-fetched email body into clean,
display-ready pieces: HTML reduced to readable text, the new message separated
from quoted history, signatures split out, and attachments classified.

It is shared by two apps with deliberately different feels — **Blick** (a
Microsoft 365 companion) and **Zirbe** (a Messages-style email client) — and is
the common floor of basic email-content handling they both stand on.

## The one rule

**Klartext handles email content. It never fetches email.** Transport (Microsoft
Graph, IMAP/MIME), authentication, threading, and all UI stay in each app.
Klartext takes strings and structured inputs and returns structured values: it
opens no socket, touches no token, and renders no view.

## Public API

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

## Design

The full design, vocabulary, marker tables, and migration map live in
[`DESIGN.md`](DESIGN.md).

## Dependency and privacy

One dependency: [SwiftSoup](https://github.com/scinfu/SwiftSoup) (MIT), used only
for HTML parsing and fully encapsulated — no SwiftSoup type crosses the public
API. Klartext is pure on-device string and DOM work: no network, no telemetry, no
off-device logging.

## Requirements

iOS 17+. Add via Swift Package Manager and pin to a tagged release.

## License

MIT. See [`LICENSE`](LICENSE).
