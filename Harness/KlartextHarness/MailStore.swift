// MailStore.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Thin wrapper over SwiftMail's IMAPServer for the harness. Holds one warm
// connection and exposes connect / list inbox / fetch one message. Credentials
// live only for the session in memory; nothing is persisted (the home dir is
// SMB-shared, so secrets must never hit disk).

import SwiftUI
import SwiftMail
import KlartextUI

@MainActor
final class MailStore: ObservableObject {
    @Published var isConnected = false
    @Published var messages: [MessageInfo] = []
    @Published var status = ""
    @Published var errorText: String?

    private var server: IMAPServer?

    /// How many of the most recent INBOX messages to load. Deep enough to cover
    /// roughly a month of typical mail so there's real variety to render against.
    private let inboxFetchLimit = 200

    func connect(host: String, port: Int, username: String, password: String) async {
        errorText = nil
        status = "Connecting…"
        do {
            let server = IMAPServer(host: host, port: port)
            try await server.connect()
            try await server.login(username: username, password: password)
            self.server = server
            isConnected = true
            await loadInbox()
        } catch {
            errorText = describe(error)
            status = ""
        }
    }

    func loadInbox() async {
        guard let server else { return }
        status = "Loading inbox…"
        errorText = nil
        do {
            let selection = try await server.selectMailbox("INBOX")
            guard let latest = selection.latest(inboxFetchLimit) else {
                messages = []
                status = "Inbox empty"
                return
            }
            let infos = try await server.fetchMessageInfosBulk(using: latest)
            messages = infos.reversed()   // newest first
            status = ""
        } catch {
            errorText = describe(error)
            status = ""
        }
    }

    /// Fetch one message in full and map SwiftMail's parts onto the toolkit's
    /// `EmailContent`. `decodedData()` gives the transfer-decoded bytes the cid
    /// renderer needs (SwiftMail's `part.data` is still base64/quoted-printable).
    func fetchContent(for info: MessageInfo) async -> EmailContent? {
        guard let server else { return nil }
        do {
            // Re-select the mailbox first: SwiftMail needs a selected mailbox for
            // the fetch, and the selection doesn't reliably persist from loadInbox
            // (Zirbe re-selects before every operation for the same reason).
            _ = try await server.selectMailbox("INBOX")
            let message = try await server.fetchMessage(from: info)
            let parts = message.parts.map { part in
                EmailPart(
                    filename: part.filename,
                    mimeType: part.contentType,
                    contentID: part.contentId,
                    disposition: disposition(from: part.disposition),
                    data: part.decodedData()
                )
            }
            return EmailContent(
                html: message.htmlBody,
                plainText: message.textBody,
                parts: parts
            )
        } catch {
            errorText = describe(error)
            return nil
        }
    }

    func signOut() async {
        try? await server?.disconnect()
        server = nil
        isConnected = false
        messages = []
        status = ""
    }

    private func disposition(from raw: String?) -> Disposition {
        switch raw?.lowercased() {
        case "inline": return .inline
        case "attachment": return .attachment
        default: return .unknown
        }
    }

    private func describe(_ error: Error) -> String {
        String(describing: error)
    }
}
