// swift-tools-version: 6.0
//
// Klartext — a shared Swift package that turns an already fetched email body
// into clean, display ready pieces. Content only: it never fetches, never
// renders, and never touches the network or a token. See DESIGN.md.

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
        .testTarget(
            name: "KlartextTests",
            dependencies: ["Klartext"],
            resources: [.copy("Corpus")]
        ),
    ]
)
