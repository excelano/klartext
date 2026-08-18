// Attachment.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// The normalized attachment model. Each app builds `RawAttachmentInput` values
// from its own transport (Graph JSON or the MIME tree); Klartext does the cid
// join against the HTML body and returns resolved `Attachment` values. Byte
// download stays in the app.

import Foundation

/// How a part presents itself, per its disposition header. Note that the header
/// is only a claim: the cid join, not this value, decides `isTrulyInline`.
public enum Disposition: Sendable, Equatable {
    case inline
    case attachment
    case unknown
}

/// A part as the app's transport reports it, before Klartext resolves whether it
/// is truly inline.
public struct RawAttachmentInput: Sendable, Equatable {
    public var filename: String?
    public var mimeType: String
    /// Size in bytes, if the transport knows it.
    public var size: Int?
    public var contentID: String?
    public var disposition: Disposition
    /// An opaque, transport-owned identifier the consumer can attach to correlate
    /// the resolved `Attachment` back to its source for byte download. Klartext
    /// stores and returns it untouched and never interprets it, so no transport
    /// logic enters the package (DESIGN.md §Attachment model: byte download stays
    /// in the app). Blick fills it with the Graph attachment id; nil when the
    /// transport has nothing to correlate against.
    public var sourceId: String?

    public init(
        filename: String?,
        mimeType: String,
        size: Int?,
        contentID: String?,
        disposition: Disposition,
        sourceId: String? = nil
    ) {
        self.filename = filename
        self.mimeType = mimeType
        self.size = size
        self.contentID = contentID
        self.disposition = disposition
        self.sourceId = sourceId
    }
}

/// A resolved attachment. `isTrulyInline` is the load bearing field: it is true
/// only when this part's Content-ID is actually referenced by a `cid:` URL in the
/// displayed HTML, regardless of what the disposition header claims.
public struct Attachment: Sendable, Equatable, Identifiable {
    /// The Content-ID, or a stable synthesized id when there is none.
    public var id: String
    public var filename: String?
    public var mimeType: String
    public var size: Int?
    public var contentID: String?
    public var disposition: Disposition
    /// Content-ID referenced by a `cid:` in the HTML body. The accurate inline test.
    public var isTrulyInline: Bool
    /// The opaque, transport-owned identifier carried through from
    /// `RawAttachmentInput` untouched, so the app can correlate this attachment
    /// back to its source for byte download. Klartext never interprets it.
    public var sourceId: String?

    public init(
        id: String,
        filename: String?,
        mimeType: String,
        size: Int?,
        contentID: String?,
        disposition: Disposition,
        isTrulyInline: Bool,
        sourceId: String? = nil
    ) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.size = size
        self.contentID = contentID
        self.disposition = disposition
        self.isTrulyInline = isTrulyInline
        self.sourceId = sourceId
    }
}

public extension Array where Element == Attachment {
    /// Attachments a human cares about: excludes truly inline parts (signature
    /// logos, tracking pixels, body referenced images).
    var userFacing: [Attachment] { filter { !$0.isTrulyInline } }
    /// The accurate paperclip predicate, unlike Graph's `hasAttachments`.
    var hasUserFacing: Bool { !userFacing.isEmpty }
}
