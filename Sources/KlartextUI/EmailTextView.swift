// EmailTextView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// The compact, native render path: a SwiftUI view over the parsed message. It
// shows the new content, folds the quoted history behind a disclosure, and sets
// the signature apart. This is the chat/glance shape; for the sender's full HTML
// design use `EmailHTMLView`.
//
// Styling is intentionally minimal so the host app's font and foreground styling
// flow through unchanged — the toolkit renders the content, the app owns the
// chrome. The new content (`visible`) inherits the host's font and color whole.
// The quoted history and signature default to a subdued foreground so they read
// as secondary with zero configuration; a host that wants its own muted color
// (e.g. a brand tint rather than system gray) passes `subduedStyle`.

#if canImport(UIKit)

import SwiftUI
import Klartext

public struct EmailTextView: View {
    private let parsed: ParsedBody
    private let subduedStyle: AnyShapeStyle
    @State private var showQuoted = false

    /// - Parameter subduedStyle: the foreground style for the quoted history and
    ///   signature, which read as secondary to the new content. Defaults to the
    ///   system `.secondary` hierarchy; pass a brand muted color to override.
    public init(
        content: EmailContent,
        options: Options = .init(),
        subduedStyle: some ShapeStyle = HierarchicalShapeStyle.secondary
    ) {
        // Parse once at init: the parse is pure and the body may re-evaluate.
        self.parsed = content.parsed(options: options)
        self.subduedStyle = AnyShapeStyle(subduedStyle)
    }

    public var body: some View {
        let visible = parsed.visible.trimmingCharacters(in: .whitespacesAndNewlines)
        let quoted = parsed.quoted?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasQuoted = !(quoted?.isEmpty ?? true)

        VStack(alignment: .leading, spacing: 12) {
            if !visible.isEmpty {
                bodyText(visible)

                if hasQuoted {
                    DisclosureGroup("Show quoted text", isExpanded: $showQuoted) {
                        bodyText(quoted!)
                            .foregroundStyle(subduedStyle)
                            .padding(.top, 4)
                    }
                    .font(.footnote)
                }
            } else if hasQuoted {
                // Bare forward: the sender wrote nothing of their own, so the
                // quoted content is the whole message. Render it directly rather
                // than hiding the only content behind the disclosure.
                bodyText(quoted!)
            }

            if let signature = parsed.signature, !signature.isEmpty {
                bodyText(signature)
                    .font(.footnote)
                    .foregroundStyle(subduedStyle)
            }
        }
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#endif
