// swift-tools-version: 6.0
//
// Klartext — a shared Swift package for handling already fetched email. The
// cross-platform `Klartext` core turns a raw body into clean, display ready
// pieces (content only: it never fetches and never touches the network or a
// token). The iOS-only `KlartextUI` layer adds drop-in SwiftUI views that
// render that content faithfully. See DESIGN.md.

import PackageDescription

let package = Package(
    name: "Klartext",
    // iOS 17+ is the product floor (matches Blick and Zirbe). macOS is declared
    // so `swift test` runs on the command line; no app links the macOS slice.
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "Klartext", targets: ["Klartext"]),
        // The iOS-only UI layer: drop-in SwiftUI views that render email content
        // faithfully (HTML in a sandboxed web view, plus a native text view). It
        // depends on the Klartext core, never on SwiftSoup. Its sources compile to
        // an empty module on the macOS slice (see the KlartextUI target), so
        // `swift test` on the cross-platform core stays green.
        .library(name: "KlartextUI", targets: ["KlartextUI"]),
    ],
    dependencies: [
        // SwiftSoup is a private implementation detail: nothing outside the
        // Klartext target may import it, and no SwiftSoup type crosses the
        // public API. Swapping it later is a one package change.
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.13.5"),
    ],
    targets: [
        .target(
            name: "Klartext",
            dependencies: ["SwiftSoup"]
        ),
        // iOS-only. WebKit/UIKit aren't usable on the macOS slice that `swift
        // test` builds, so every source in this target wraps its whole body in
        // `#if canImport(UIKit)` and compiles to an empty module on macOS. The
        // target links only the Klartext core, so it cannot import SwiftSoup —
        // the encapsulation rule is enforced by construction.
        .target(
            name: "KlartextUI",
            dependencies: ["Klartext"]
        ),
        .testTarget(
            name: "KlartextTests",
            dependencies: ["Klartext"],
            resources: [.copy("Corpus")]
        ),
    ]
)
