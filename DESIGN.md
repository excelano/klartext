# Klartext — design

Klartext is a shared Swift package that turns a raw, already fetched email body into
clean, display ready pieces. It is consumed by two apps with different goals: **Blick**
(a Microsoft 365 companion that surfaces Calendar, Teams, and Email at a glance) and
**Zirbe** (a general email client with a texting feel). The two apps deliberately feel
different. Klartext is the common floor of basic email content handling they both stand on.

The name is the German word for plain text, and idiomatically for plain speaking. That is
what the package does: it takes messy HTML and quoted clutter and returns the clear version
of the message. It sits beside Blick and Zirbe as a short German noun.

This document is the design only. No code has been written yet.

---

## 1. The one line that governs everything

**Klartext handles email content. It never fetches email.**

The two apps reach their mail through completely different pipes. Blick talks to Microsoft
Graph over REST with MSAL; Zirbe talks IMAP over SwiftMail and parses raw MIME. Those
transport layers cannot and must not be shared inside Klartext. What the apps share is
everything above the wire: given a body that has already arrived, do the text work.

| Inside Klartext (shared) | Stays in each app (per consumer) |
|---|---|
| HTML to text reduction | Fetch and transport (Graph client, IMAP engine) |
| Quote and history detection (the seam) | Authentication and tokens (MSAL, IMAP credentials) |
| `fold` (keep both sides) and `extract` / `preview` (gist only) | Conversation and thread grouping (Graph server side; Zirbe from IMAP) |
| Signature detection and separation | Attachment byte download (Graph `$value`, IMAP `FETCH BODY[part]`) |
| Reply quote trailer construction | All UI chrome, navigation, and rendering |
| Normalized attachment model and inline classification | Each app's own bubble and sheet styling |

If transport logic ever creeps into Klartext it becomes a tangle of Graph mode versus IMAP
mode branches and the value evaporates. The rule that protects the boundary: a thing goes
into Klartext only when it has two real consumers and is genuinely consumer neutral.

---

## 2. Glossary

The shared vocabulary, so the two codebases stop inventing parallel names.

| Term | Definition |
|---|---|
| **Quoted text / history** | Content from earlier messages reproduced in a reply for context. |
| **Quote prefix / depth** | Leading `>` characters in plain text (RFC 3676); count is the depth (`>>` is depth 2). |
| **Blockquote** | The HTML container for quoted content; nesting maps to quote depth. |
| **Attribution line** | The "On \<date\>, \<person\> wrote:" credit immediately above a quoted block. Often spans multiple lines. |
| **Signature block** | The author trailer at message end. |
| **Signature delimiter** | The conventional `"-- \n"` (dash dash space newline). The trailing space is load bearing and frequently mangled. |
| **The seam** | The boundary between the new message and everything that follows it (quote plus signature). |
| **Fold** | Split at the seam, keep both sides, hide the lower one. Zirbe's reader behavior; lossless. |
| **Extract / preview** | Cut at the seam, keep only the top, then strip salutation and signature for a glance. Lossy. Blick's list behavior. |
| **Truly inline** | An attachment part whose Content-ID is actually referenced by a `cid:` URL in the displayed HTML. Anything else is a real attachment, even if its disposition says inline. |
| **`uniqueBody`** | Microsoft Graph's server side best effort "new content only" field. A heuristic, not a contract. |

---

## 3. Architecture and principles

**Encapsulation: SwiftSoup is an implementation detail.** Klartext uses SwiftSoup (a
mature, MIT, pure on device DOM parser) for HTML, because detecting quotes by container
(`blockquote` nesting, `div.gmail_quote`, `div#divRplyFwdMsg`) is a DOM selector job that
regex does badly. But SwiftSoup is a private dependency. Nothing outside Klartext may
`import SwiftSoup`, and no SwiftSoup type (`Document`, `Element`, `Node`) ever crosses the
public API. The public surface is our own value types and plain Swift strings. Done this
way, swapping SwiftSoup out later, for a hand rolled parser or the iOS 26 on device model,
is a one package change with zero churn in Blick or Zirbe.

**Avoid `NSAttributedString(html:)`.** It is WebKit backed, effectively main thread bound,
slow, and crashes off the main thread. Both apps correctly avoid it today. Klartext must
never reach for it as a "simpler" path. This is stated so nobody simplifies into the trap
later.

**No fetch, no UI.** Klartext takes strings and structured inputs and returns structured
values. It opens no sockets, touches no Keychain, and renders no views.

**One parse, two consumption modes.** The extract/fold duality is not two algorithms. It is
one seam detection followed by two ways of consuming the result. Zirbe reads `visible` plus
`quoted`; Blick reads `preview()` for the glance and the same `visible` / `quoted` for the
full sheet.

**The attachment seam is designed in, built later.** The content model carries an
attachments list from day one so we never reshape it, but the first build of attachment
handling is small (Blick's accurate paperclip) and Zirbe's full handling lands when its
roadmap reaches it.

---

## 4. Public API (SwiftSoup free)

```swift
// A fully parsed, display ready view of one message body.
public struct ParsedBody: Sendable, Equatable {
    public var visible: String          // the new content (the sender's reply)
    public var quoted: String?          // history and everything below the seam; nil if none
    public var signature: String?       // detected signature block, if separated out
    public var sourceFormat: BodyFormat // .plainText or .html (what was parsed)
    public var attachments: [Attachment]
}

public enum BodyFormat: Sendable { case plainText, html }

public enum Klartext {
    /// Parse a raw body into structured pieces. Pass whichever representations you
    /// have. HTML is preferred when present because container based quote detection
    /// is more reliable than text heuristics.
    public static func parse(
        plainText: String? = nil,
        html: String? = nil,
        attachments: [RawAttachmentInput] = [],
        options: Options = .init()
    ) -> ParsedBody

    /// Reduce HTML to readable plain text: block aware line breaks, entities decoded.
    /// Used internally by parse(); exposed for callers that only need text.
    public static func plainText(fromHTML html: String) -> String

    /// Build a conventional reply quote trailer ("On <date>, <sender> wrote:" plus
    /// > prefixed lines). Used by Zirbe today; available to Blick if it gains reply.
    public static func replyQuoteTrailer(
        body: String, from sender: String, date: Date,
        locale: Locale = .current, timeZone: TimeZone = .current
    ) -> String
}

public struct Options: Sendable {
    public var separateSignature: Bool = true  // split signature into ParsedBody.signature
    public var maxScanLines: Int? = nil         // bound signature/marker search for huge bodies
    public init() {}
}

public extension ParsedBody {
    /// Aggressively cleaned single glance preview of the new content: salutation,
    /// signature, and trailing valediction removed. Lossy by design. Blick's unread
    /// list and the default of its preview sheet use this; the full `visible` and
    /// `quoted` stay available for "Show full message".
    func preview(maxLength: Int? = nil) -> String
}
```

### Attachment model

Each app builds `RawAttachmentInput` values from its own transport (Graph JSON or the MIME
tree). Klartext does the cid join against the HTML body and returns resolved `Attachment`
values. Byte download stays in the app.

```swift
public enum Disposition: Sendable { case inline, attachment, unknown }

public struct RawAttachmentInput: Sendable {
    public var filename: String?
    public var mimeType: String
    public var size: Int?            // bytes, if the transport knows
    public var contentID: String?
    public var disposition: Disposition
    public init(filename: String?, mimeType: String, size: Int?,
                contentID: String?, disposition: Disposition)
}

public struct Attachment: Sendable, Equatable, Identifiable {
    public var id: String            // contentID, or a stable synthesized id
    public var filename: String?
    public var mimeType: String
    public var size: Int?
    public var contentID: String?
    public var disposition: Disposition
    public var isTrulyInline: Bool   // contentID referenced by a cid: in the HTML body
}

public extension Array where Element == Attachment {
    /// Attachments a human cares about: excludes truly inline images (signature
    /// logos, tracking pixels, embedded screenshots referenced from the body).
    var userFacing: [Attachment] { filter { !$0.isTrulyInline } }
    /// Blick's paperclip predicate. Accurate, unlike Graph's hasAttachments.
    var hasUserFacing: Bool { !userFacing.isEmpty }
}
```

The load bearing rule: a part is **truly inline only when its Content-ID is actually
referenced by a `cid:` URL in the displayed HTML**, regardless of what its disposition
header says. An "inline" part nobody references is a real attachment. No off the shelf
library does this HTML to parts join, and it is exactly what makes Blick's paperclip and
Zirbe's attachment list correct rather than approximately right.

---

## 5. Seam detection: the markers

Plain text and HTML use different mechanisms. The text heuristics are ported (logic, not
code) primarily from `mail-parser-reply` (Python, MIT, actively maintained, multilingual),
with the Talon and email_reply_parser families as supporting references.

### HTML (container based, via SwiftSoup)

| Signal | Reliability | Note |
|---|---|---|
| `div.gmail_quote` / `blockquote.gmail_quote` | High | Most dependable single signal. |
| `<blockquote>` nesting | High | Structural; nesting equals depth. |
| `div#divRplyFwdMsg` preceded by `<hr>` | Medium | Modern Outlook / OWA reply header. |
| `blockquote[type=cite]`, `div.moz-cite-prefix` | Positive hint only | Apple Mail and Thunderbird; absence proves nothing. |
| `*_quote` substring match | Required guard | New Outlook.com rewrites classes with an `x_` prefix, so match the substring, never the exact class. |
| `<hr>` alone | Low | Ambiguous with body content; usable only with an adjacent header block. |

### Plain text

| Marker | Reliability | Note |
|---|---|---|
| `>` prefix and depth | High under `format=flowed`, otherwise medium | Hard wrapped non flowed lines can lose the leading `>`. **Blick does not detect this today; Klartext gives it to Blick.** |
| `-----Original Message-----` | High | Fixed ASCII, low false positive. |
| `Begin forwarded message:` | High | Apple forward marker. |
| Attribution line ("On … wrote:") | Medium | Walk backward to wrap the full multi line attribution (Zirbe already does this; Blick does not). Localized verbs (schrieb, escribió, a écrit) need the multilingual table. |
| `From:` / `Sent:` / `To:` / `Subject:` header block | Medium | Outlook reply header; require two or more labels. **Zirbe does not detect this today; Klartext gives it to Zirbe.** |
| Signature delimiter `-- ` | Medium | Trailing space often stripped in the wild. |
| Mobile signature ("Sent from my …") | Medium | Open ended per vendor and locale list. |
| Valediction on its own line ("Thanks,", "Regards,") | Low, preview only | Used only by `preview()`'s aggressive cleanup, never by `fold`, because a mid message valediction is a real false positive risk. |

Detection takes the earliest valid seam. The mirror of Talon's strategy applies: when HTML
container detection yields nothing, reduce to text and rerun the text markers, so the HTML
path still benefits from the text heuristics on top posted mail with no container.

---

## 6. How each app consumes Klartext

### Blick (the M365 companion)

The unread list stays a lossy glance: `parsed.preview(maxLength:)`. Folding is meaningless
in a one line cell.

The MessagePreviewSheet changes, and this is the fix that matters. Today it fetches the full
body and then runs the aggressive cleaner, destroying part of it with no way to get it back;
a wrong cut means the user reads a silently truncated message. Klartext makes the sheet a
hybrid: `parsed.preview()` is the default visible text (clean, gist), and a "Show full
message" affordance reveals `parsed.visible` plus the foldable `parsed.quoted`. Glance clean
by default, full text on demand, nothing ever destroyed. Blick keeps its character without
the truncation bug.

Attachments: Blick's first cut is an accurate paperclip via `attachments.hasUserFacing`,
which excludes inline signature logos that make Graph's `hasAttachments` lie. Nothing more
for now; this stays inside "M365 at a glance," not a full reader.

Out of scope for this plan and decided separately: rendering formatted HTML in Blick (it
forces plain text from Graph today), and surrounding thread context (a Graph conversation
feature that flirts with reader territory).

### Zirbe (the email client)

Zirbe's behavior is preserved, moved onto the shared core. `QuotedText.fold` becomes
`Klartext.parse(...).visible` / `.quoted`; `QuotedText.replyBody` / `quoteTrailer` becomes
`Klartext.replyQuoteTrailer`; `HTMLText.plainText` becomes `Klartext.plainText(fromHTML:)`.
The WKWebView "Web View" that renders raw HTML stays in Zirbe; Klartext does not render.

Zirbe gains the Outlook `From:` header block detection and the SwiftSoup based HTML
container detection it lacks today. Full attachment handling (list, open, save, attach on
compose) lands when Zirbe's roadmap reaches it, on the model Klartext already exposes.

---

## 7. Migration map

| App | Today | Becomes |
|---|---|---|
| Blick | `PreviewCleaner.cleanEmailPreview` (`CheckIn/Utilities/PreviewCleaner.swift:84`) | `ParsedBody.preview()` (list) and `parse()` (sheet) |
| Blick | `HTMLStripper.stripHTML` (`CheckIn/Utilities/HTMLStripper.swift:30`) | `Klartext.plainText(fromHTML:)` |
| Blick | (no `>` quote detection) | gained via Klartext text markers |
| Blick | `hasAttachments` paperclip | `attachments.hasUserFacing` |
| Zirbe | `QuotedText.fold` (`Packages/ZirbeCore/.../QuotedText.swift:117`) | `Klartext.parse(...).visible` / `.quoted` |
| Zirbe | `QuotedText.replyBody` / `quoteTrailer` | `Klartext.replyQuoteTrailer` |
| Zirbe | `HTMLText.plainText` (`Packages/ZirbeMail/.../HTMLText.swift`) | `Klartext.plainText(fromHTML:)` |
| Zirbe | (no Outlook `From:` block, regex only HTML) | gained via Klartext markers and SwiftSoup |

**Behavior preservation.** Before migrating either app, capture golden tests from the
current outputs of both `PreviewCleaner` and `QuotedText` against a shared corpus of real
sample bodies (plain and HTML, Gmail, Outlook, Apple Mail, forwarded, top posted, nested).
Klartext must match those outputs, or any intentional improvement (Blick gaining `>`
detection, Zirbe gaining `From:` detection) is documented as a deliberate diff with its own
test. The corpus lives in the Klartext repo and is the regression suite for both apps.

---

## 8. Packaging, dependency, and privacy

Standalone SPM package in its own repo, `excelano/klartext`, **public, MIT**. Zirbe is
already public and MIT and would hold this logic anyway, so extracting it to a public package
adds zero new exposure; Blick simply links it, and linking a public package does not publish
Blick's source. Platform floor iOS 17+ (matching both apps). Single third party dependency:
SwiftSoup (MIT). Both apps add Klartext as an SPM dependency and pin to a released version.

**Privacy posture.** Klartext is pure on device string and DOM work. It opens no network
connection, defines no new external destination, moves no token, and ships no analytics,
telemetry, or off device logger. SwiftSoup is a pure on device MIT library with no network
behavior; David explicitly approved it as the one new dependency. Nothing about Klartext
moves data off the device that obtained it. It respects Blick's token on device boundary in
full, because it never touches tokens or the network at all.

---

## 9. Suggested build order

The first concrete step is this document. When build starts, the order that proves the
package early and keeps both apps shippable throughout:

1. **Stand up the package.** `excelano/klartext`, SPM, MIT, iOS 17+, SwiftSoup pinned. Define
   `ParsedBody`, `Attachment`, `RawAttachmentInput`, `Options`, the public `Klartext` enum
   skeleton. Test scaffolding and the sample corpus.
2. **HTML reducer.** Implement `plainText(fromHTML:)` over SwiftSoup with a custom node
   visitor that emits newlines on block and `<br>` boundaries (SwiftSoup's `.text()` flattens
   line breaks, so this is required). Golden test against both apps' current strippers. This
   alone retires the duplicated `HTMLStripper` / `HTMLText` code and proves the sharing model.
3. **Seam and parse.** Implement seam detection (HTML containers, then text markers) and
   `parse()` producing `visible` / `quoted`. Port Zirbe's multi line attribution wrapping and
   Blick's marker set, unify, add the two cross gains (`>` for Blick, `From:` for Zirbe).
4. **Signature and preview.** Signature separation behind `Options.separateSignature`, then
   `ParsedBody.preview()` carrying Blick's aggressive glance cleanup as a layer over `visible`.
5. **Attachments.** `classifyAttachments` cid join and `Attachment` / `userFacing`.
6. **Migrate.** Zirbe first (behavior preserving, it has the richer existing tests), then
   Blick's sheet to the hybrid and list to `preview()`, then Blick's accurate paperclip.

---

## 10. Out of scope, and the future

Named here so they do not quietly creep into Klartext or get lost.

A future **transport** module is a separate question from Klartext. If Zirbe's backlog
reaches M365 or Google, the shareable thing becomes Blick's Graph client, and that would be
its own shared package governed by the same two consumer rule. Content and transport stay
distinct modules. Design for it; do not build it now.

The **HTML render view** (WKWebView) stays Zirbe's. Klartext does not render. Revisit only if
Blick decides to show formatted HTML, which is a real product step separate from fixing
truncation.

**Thread and conversation context** in Blick is a Graph feature, not a Klartext concern.

**iOS 26 FoundationModels** (Apple's on device LLM, no backend, in posture) could one day do
seam or signature detection with a model. Because SwiftSoup and the heuristics are fully
encapsulated, such a backend could slot in behind the same public API later. It is hardware
gated, so it could never be the only path; the heuristic core remains the floor. Noted as a
future option, not a v1 dependency.

---

## 11. Conventions

New Swift files in the Klartext repo carry the standard header (file name, `// Author: David
M. Anderson`, `// Built with AI assistance (Claude, Anthropic)`). Commits use the
`Co-Authored-By: Claude <noreply@anthropic.com>` trailer and David's git identity. Releases
are tagged `vMAJOR.MINOR.PATCH`; both apps pin to a tag.
