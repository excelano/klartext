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

    public init(
        filename: String?,
        mimeType: String,
        size: Int?,
        contentID: String?,
        disposition: Disposition
    ) {
        self.filename = filename
        self.mimeType = mimeType
        self.size = size
        self.contentID = contentID
        self.disposition = disposition
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

    public init(
        id: String,
        filename: String?,
        mimeType: String,
        size: Int?,
        contentID: String?,
        disposition: Disposition,
        isTrulyInline: Bool
    ) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.size = size
        self.contentID = contentID
        self.disposition = disposition
        self.isTrulyInline = isTrulyInline
    }
}

public extension Array where Element == Attachment {
    /// Attachments a human cares about: excludes truly inline parts (signature
    /// logos, tracking pixels, body referenced images).
    var userFacing: [Attachment] { filter { !$0.isTrulyInline } }
    /// The accurate paperclip predicate, unlike Graph's `hasAttachments`.
    var hasUserFacing: Bool { !userFacing.isEmpty }
}
