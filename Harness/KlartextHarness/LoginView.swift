// LoginView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// IMAP sign-in. Host, port, username, and password are held in @State only and
// passed straight to the connection; nothing is stored, defaulted from disk, or
// remembered between launches.

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var store: MailStore

    @State private var host = ""
    @State private var port = "993"
    @State private var username = ""
    @State private var password = ""
    @State private var connecting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("IMAP server") {
                    TextField("Host (e.g. imap.fastmail.com)", text: $host)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                }
                Section("Account") {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                }
                if let error = store.errorText {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    Button {
                        Task {
                            connecting = true
                            // Trim whitespace and newlines off everything but the
                            // password (a password may legitimately contain
                            // spaces). iOS autofill/QuickType often appends a
                            // trailing space to the email, which the server then
                            // rejects as a bad username — Zirbe trims the same way.
                            await store.connect(
                                host: host.trimmingCharacters(in: .whitespacesAndNewlines),
                                port: Int(port.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 993,
                                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                                password: password
                            )
                            connecting = false
                        }
                    } label: {
                        if connecting {
                            HStack { ProgressView(); Text(store.status.isEmpty ? "Connecting…" : store.status) }
                        } else {
                            Text("Connect")
                        }
                    }
                    .disabled(connecting || host.isEmpty || username.isEmpty)
                }
            }
            .navigationTitle("Klartext Harness")
        }
    }
}
