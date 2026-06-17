// EmailContent.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// The single hand-off type from a consuming app to KlartextUI. The app fetches a
// message over its own transport (Graph, IMAP, anything) and fills an
// `EmailContent`; the toolkit renders it. KlartextUI never fetches.
//
// `EmailPart` carries the part bytes, which the Klartext core's own attachment
// model deliberately omits (the core never needs bytes; the renderer does, to
// serve `cid:` inline images on device without touching the network).
//
// The whole file is guarded for iOS: KlartextUI is an iOS-only product, and this
// keeps it compiling to an empty module on the macOS slice that `swift test`
// builds for the cross-platform core.

#if canImport(UIKit)

import Foundation
// Re-export the core so an app needs only `import KlartextUI` to name the shared
// value types it fills these views with (Disposition, Options, ParsedBody, …).
@_exported import Klartext

/// One MIME part of a fetched message, as the app's transport reports it. `data`
/// is the decoded part bytes; it is needed only to render `cid:` inline images
/// and may be `nil` for a part whose bytes the app hasn't fetched (the renderer
/// then shows the broken-image glyph rather than failing).
public struct EmailPart: Sendable, Equatable {
    public var filename: String?
    public var mimeType: String
    public var contentID: String?
    public var disposition: Disposition
    public var data: Data?

    public init(
        filename: String? = nil,
        mimeType: String,
        contentID: String? = nil,
        disposition: Disposition = .unknown,
        data: Data? = nil
    ) {
        self.filename = filename
        self.mimeType = mimeType
        self.contentID = contentID
        self.disposition = disposition
        self.data = data
    }
}

/// A fetched message's renderable content. Supply whichever representations the
/// transport gave you; the views prefer `html` when present and fall back to
/// `plainText`. `parts` carries attachments and inline resources.
public struct EmailContent: Sendable, Equatable {
    public var html: String?
    public var plainText: String?
    public var parts: [EmailPart]

    public init(
        html: String? = nil,
        plainText: String? = nil,
        parts: [EmailPart] = []
    ) {
        self.html = html
        self.plainText = plainText
        self.parts = parts
    }
}

public extension EmailContent {
    /// Run the Klartext content parse over this message, mapping `parts` to the
    /// core's byte-free `RawAttachmentInput`. This is the one place the bytes are
    /// dropped on the way into the core, so `EmailTextView` and any caller that
    /// wants `visible` / `quoted` / `attachments` share identical results.
    func parsed(options: Options = .init()) -> ParsedBody {
        Klartext.parse(
            plainText: plainText,
            html: html,
            attachments: parts.map {
                RawAttachmentInput(
                    filename: $0.filename,
                    mimeType: $0.mimeType,
                    size: $0.data?.count,
                    contentID: $0.contentID,
                    disposition: $0.disposition
                )
            },
            options: options
        )
    }
}

#endif
