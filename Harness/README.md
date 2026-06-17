# KlartextHarness

A bare-bones IMAP email reader that exists for one reason: to exercise **KlartextUI**'s
rendering views against real mail on the iOS simulator. It is not a product and not part
of the Klartext Swift package. It connects to an IMAP account, lists the inbox, and renders
a selected message through `EmailHTMLView` (the faithful web render) and `EmailTextView`
(the native fold), with a toggle for the remote-image gate. There is no persistence, no
settings, and no feature beyond connect, list, render.

## Why it is not part of the package

The harness is a standalone Xcode application with its own dependency on
[SwiftMail](https://github.com/Cocoanetics/SwiftMail) for IMAP. That dependency is declared
inside the generated Xcode project, never in the package's `Package.swift`, so it stays out
of Klartext's dependency graph entirely. A consumer of `Klartext` or `KlartextUI` resolves
only SwiftSoup and never sees SwiftMail. The generated project and its build output are
gitignored; the generator script and the Swift sources are what get committed, in the same
spirit as a Tuist or XcodeGen project spec.

## Generating and running

The Xcode project is produced by a Ruby script rather than checked in, which keeps the
generated `.xcodeproj` churn out of history.

1. Install the generator gem once: `gem install xcodeproj`.
2. From the repository root, generate the project: `ruby Harness/generate_project.rb`.
3. Open `Harness/KlartextHarness.xcodeproj` in Xcode, or build it from the command line
   with `xcodebuild -project Harness/KlartextHarness.xcodeproj -scheme KlartextHarness
   -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`.
4. Run it on a simulator and enter your IMAP host, port, username, and password.

## Credentials

The host, port, username, and password are held in memory for the duration of the session
only. Nothing is written to disk, defaulted from disk, or remembered between launches. Sign
Out drops the connection and clears the in-memory session.
