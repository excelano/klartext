// TextSeam.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Finds the seam in a plain-text body: the boundary between the new message and
// the quoted history below it. This unifies Zirbe's boundary detection (the `>`
// prefix, the "wrote:" attribution with its multi-line back-walk, the forwarded
// and Original-Message markers) with Blick's Outlook "From:" header-block
// detection, so each app gains the marker the other already had.
//
// Detection takes the earliest valid seam: lines are scanned top down and the
// first marker wins. The split is recoverable by design — a mis-fold hides text
// behind an expand control, it never destroys it — so the heuristics lean toward
// folding rather than missing a quote.

import Foundation

enum TextSeam {

    /// Split `body` at the first quoted-history boundary. Everything above it is
    /// `visible`; everything from it down is `quoted`. With no boundary the whole
    /// body is `visible` and `quoted` is `nil`. A body that is entirely quoted (a
    /// bare forward) returns an empty `visible` and the text as `quoted`.
    static func split(_ body: String, options: Options = .init()) -> (visible: String, quoted: String?) {
        let normalized = body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")

        guard let cut = boundaryIndex(in: lines, maxScanLines: options.maxScanLines) else {
            return (normalized.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }

        let visible = lines[..<cut].joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let quoted = lines[cut...].joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (visible, quoted.isEmpty ? nil : quoted)
    }

    // MARK: - Boundary detection

    /// The index of the first line that begins the quoted history, or nil if the
    /// body carries none. Recognizes a `>`-quoted line, an Outlook
    /// "From:/Sent:/To:/Subject:" header block, the Outlook "Original Message" and
    /// Apple "Begin forwarded message:" separators, and an attribution line ending
    /// in "wrote:", whichever comes first.
    private static func boundaryIndex(in lines: [String], maxScanLines: Int?) -> Int? {
        let limit = maxScanLines.map { min($0, lines.count) } ?? lines.count
        for index in 0..<limit {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix(">") { return index }
            if isForwardOrOriginalMarker(line) { return index }
            if isOutlookHeaderBlock(at: index, in: lines) { return index }
            if line.range(of: #"\bwrote:$"#, options: .regularExpression) != nil {
                return attributionStart(of: index, in: lines)
            }
        }
        return nil
    }

    /// An attribution can wrap across lines ("On Mon, Jun 9, 2026\nDavid <x>
    /// wrote:"). Given the line ending in "wrote:", walk back over the contiguous
    /// non-blank block above it; if that block begins with "On ", the boundary is
    /// its first line so the whole attribution folds together. Otherwise the
    /// "wrote:" line stands alone as the boundary.
    private static func attributionStart(of index: Int, in lines: [String]) -> Int {
        var start = index
        var cursor = index - 1
        while cursor >= 0 {
            let line = lines[cursor].trimmingCharacters(in: .whitespaces)
            if line.isEmpty { break }
            start = cursor
            if line.hasPrefix("On ") { break }
            cursor -= 1
        }
        return lines[start].trimmingCharacters(in: .whitespaces).hasPrefix("On ") ? start : index
    }

    private static func isForwardOrOriginalMarker(_ line: String) -> Bool {
        line.range(of: #"^-{2,}\s*Original Message\s*-{2,}$"#, options: [.regularExpression, .caseInsensitive]) != nil
            || line.caseInsensitiveCompare("Begin forwarded message:") == .orderedSame
    }

    /// Any of the header labels Outlook stacks above a quoted reply.
    private static let headerLabelPattern = #"^(from|sent|to|cc|bcc|subject|date|reply-to)\s*:"#

    /// True when `index` begins an Outlook quoted-reply header: a "From:" line
    /// followed within a short window by at least one more header label. The two
    /// label requirement keeps an ordinary sentence that opens "From: the desk of
    /// …" from being mistaken for a quote boundary.
    private static func isOutlookHeaderBlock(at index: Int, in lines: [String]) -> Bool {
        let first = lines[index].trimmingCharacters(in: .whitespaces)
        guard first.range(of: #"^from\s*:"#, options: [.regularExpression, .caseInsensitive]) != nil else {
            return false
        }
        var labels = 0
        for i in index..<min(index + 5, lines.count) {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.range(of: headerLabelPattern, options: [.regularExpression, .caseInsensitive]) != nil {
                labels += 1
            }
        }
        return labels >= 2
    }
}
