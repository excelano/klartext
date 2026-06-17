// KlartextHarnessApp.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// A bare-bones IMAP email reader whose only purpose is to exercise KlartextUI's
// rendering views against real mail. It is NOT a product: no persistence, no
// settings, no features beyond connect → list → render. Credentials are held in
// memory only and never written to disk.

import SwiftUI

@main
struct KlartextHarnessApp: App {
    @StateObject private var store = MailStore()

    var body: some Scene {
        WindowGroup {
            if store.isConnected {
                InboxView()
                    .environmentObject(store)
            } else {
                LoginView()
                    .environmentObject(store)
            }
        }
    }
}
