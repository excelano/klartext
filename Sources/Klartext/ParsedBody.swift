// ParsedBody.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// The structured, display ready result of parsing one message body. One parse
// feeds two consumption modes: Zirbe reads `visible` plus `quoted`; Blick reads
// `preview()` for the glance and the same fields for the full sheet.

import Foundation

/// Which representation `parse()` actually worked from.
public enum BodyFormat: Sendable, Equatable {
    case plainText
    case html
}

/// A fully parsed view of one message body, split at the seam between the new
/// content and the quoted history below it.
public struct ParsedBody: Sendable, Equatable {
    /// The new content: the sender's own reply, above the seam.
    public var visible: String
    /// History and everything below the seam; `nil` when there is none.
    public var quoted: String?
    /// The detected signature block, separated out when `Options.separateSignature`
    /// is on; `nil` otherwise or when none is found.
    public var signature: String?
    /// The representation that was parsed.
    public var sourceFormat: BodyFormat
    /// The message's attachments, with inline classification resolved.
    public var attachments: [Attachment]

    public init(
        visible: String,
        quoted: String? = nil,
        signature: String? = nil,
        sourceFormat: BodyFormat,
        attachments: [Attachment] = []
    ) {
        self.visible = visible
        self.quoted = quoted
        self.signature = signature
        self.sourceFormat = sourceFormat
        self.attachments = attachments
    }
}
