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
// chrome.

#if canImport(UIKit)

import SwiftUI
import Klartext

public struct EmailTextView: View {
    private let parsed: ParsedBody
    @State private var showQuoted = false

    public init(content: EmailContent, options: Options = .init()) {
        // Parse once at init: the parse is pure and the body may re-evaluate.
        self.parsed = content.parsed(options: options)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(parsed.visible)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let quoted = parsed.quoted, !quoted.isEmpty {
                DisclosureGroup("Show quoted text", isExpanded: $showQuoted) {
                    Text(quoted)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
                .font(.footnote)
            }

            if let signature = parsed.signature, !signature.isEmpty {
                Text(signature)
                    .textSelection(.enabled)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#endif
