// MessageView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Renders one message through KlartextUI. A segmented control switches between
// the rich web render (EmailHTMLView) and the native text render (EmailTextView);
// a toggle flips the remote-image gate on the rich view. This is the surface the
// toolkit is verified against.

import SwiftUI
import SwiftMail
import KlartextUI

struct MessageView: View {
    let info: MessageInfo
    @EnvironmentObject private var store: MailStore

    @State private var content: EmailContent?
    @State private var mode: Mode = .rich
    @State private var loadRemoteImages = false
    @State private var loading = true

    enum Mode: String, CaseIterable, Identifiable {
        case rich = "Rich"
        case text = "Text"
        var id: Self { self }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()

            if mode == .rich {
                Toggle("Load remote images", isOn: $loadRemoteImages)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            Divider()

            if loading {
                Spacer()
                ProgressView("Fetching…")
                Spacer()
            } else if let content {
                switch mode {
                case .rich:
                    EmailHTMLView(content: content, allowRemoteContent: loadRemoteImages)
                        .id("rich-\(info.sequenceNumber)")
                case .text:
                    ScrollView {
                        EmailTextView(content: content)
                            .padding()
                    }
                }
            } else {
                Spacer()
                Text(store.errorText ?? "No content")
                    .foregroundStyle(.secondary)
                    .padding()
                Spacer()
            }
        }
        .navigationTitle(info.subject ?? "(no subject)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            content = await store.fetchContent(for: info)
            loading = false
        }
    }
}
