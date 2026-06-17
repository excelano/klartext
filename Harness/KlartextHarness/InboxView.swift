// InboxView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// The most recent INBOX messages, newest first. Tap one to render it.

import SwiftUI
import SwiftMail

struct InboxView: View {
    @EnvironmentObject private var store: MailStore

    var body: some View {
        NavigationStack {
            List {
                if !store.status.isEmpty {
                    Text(store.status).foregroundStyle(.secondary)
                }
                ForEach(Array(store.messages.enumerated()), id: \.offset) { _, info in
                    NavigationLink {
                        MessageView(info: info)
                            .environmentObject(store)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(info.subject ?? "(no subject)")
                                .font(.headline)
                                .lineLimit(1)
                            Text(info.from ?? "(unknown sender)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .navigationTitle("Inbox")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sign Out") { Task { await store.signOut() } }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await store.loadInbox() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
}
