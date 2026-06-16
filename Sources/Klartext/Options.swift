// Options.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Knobs for a parse. Defaults match the common case: separate the signature, and
// scan the whole body.

import Foundation

public struct Options: Sendable, Equatable {
    /// Split a detected signature into `ParsedBody.signature` instead of leaving
    /// it in `visible`.
    public var separateSignature: Bool
    /// Upper bound on the line scan for signature and seam markers, for very large
    /// bodies; `nil` scans the whole body.
    public var maxScanLines: Int?

    public init(separateSignature: Bool = true, maxScanLines: Int? = nil) {
        self.separateSignature = separateSignature
        self.maxScanLines = maxScanLines
    }
}
