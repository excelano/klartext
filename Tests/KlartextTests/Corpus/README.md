# Klartext sample corpus

Real-world email bodies used as golden fixtures for the regression suite shared by
Blick and Zirbe. Each algorithm step adds cases here and asserts Klartext's output
against captured expectations, so any change to parsing is a visible, intentional diff.

Planned layout (filled in as the algorithms land, per DESIGN.md §9):

- `html/` — HTML bodies: Gmail (`gmail_quote`), Outlook / OWA (`divRplyFwdMsg`,
  `x_`-prefixed classes), Apple Mail (`blockquote[type=cite]`), Thunderbird
  (`moz-cite-prefix`), nested replies, forwarded.
- `plaintext/` — plain bodies: `>`-quoted (flowed and hard-wrapped), Outlook
  `From:`/`Sent:` header blocks, `-----Original Message-----`, Apple
  `Begin forwarded message:`, top-posted with no markers, multilingual attribution
  lines (schrieb / escribió / a écrit).
- `expected/` — captured `visible` / `quoted` / `signature` / `preview` outputs,
  including golden captures from each app's current code before migration so
  behavior is preserved (deliberate improvements documented as their own diff).

This folder is copied into the test bundle as a resource (see `Package.swift`).
Do not add anything here that isn't a sample body or its expected output.
