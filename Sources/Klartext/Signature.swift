// Signature.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Separates a trailing signature block off the new message. This runs on
// `visible` (after the seam split) and only on the conventional, low-false-
// positive markers: the RFC 3676 "-- " delimiter (its trailing space is often
// stripped in the wild, so a bare "--" line counts) and the common mobile/auto
// signatures ("Sent from my iPhone", "Get Outlook for iOS"). The aggressive,
// preview-only cues (valediction lines, salutations) are deliberately NOT here —
// they belong to preview()'s lossy glance, never to a lossless fold, because a
// mid-message "Thanks," is a real false positive.

import Foundation

enum Signature {

    /// Split `text` into its body and a trailing signature. Returns a nil
    /// signature when separation is disabled or no delimiter is found, leaving
    /// `text` whole as the body.
    static func separate(_ text: String, options: Options) -> (body: String, signature: String?) {
        guard options.separateSignature else { return (text, nil) }

        let lines = text.components(separatedBy: "\n")
        guard let bounds = signatureBounds(in: lines) else { return (text, nil) }

        let body = lines[..<bounds.bodyEnd].joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let signature = lines[bounds.signatureStart...].joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (body, signature.isEmpty ? nil : signature)
    }

    /// Mobile and auto-appended signatures that vendors stamp on their own line.
    private static let mobilePattern =
        #"^(sent from my .{0,30}|sent from outlook.*|get outlook for.*|sent via .*)$"#

    /// Where the body ends and the signature begins, or nil if there is no
    /// signature. The `--` delimiter is a marker only, so the signature starts on
    /// the line after it; a mobile/auto footer is itself part of the signature, so
    /// the signature starts on that line.
    private static func signatureBounds(in lines: [String]) -> (bodyEnd: Int, signatureStart: Int)? {
        for (index, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line == "--" { return (bodyEnd: index, signatureStart: index + 1) }
            if line.range(of: mobilePattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return (bodyEnd: index, signatureStart: index)
            }
        }
        return nil
    }
}
