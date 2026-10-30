---
status: accepted
---

# Use native Omarchy QML and GitHub CLI

Build Omarchy GitHub Stats as a native Quickshell plugin using QML/JavaScript and Omarchy's popup and theme components. Access GitHub through asynchronous `gh api` calls, with one host-managed data service shared by monitor widgets, so authentication, polling, and account data have a clear owner.

This choice fits the installed Omarchy 4 bar and reuses GitHub CLI's credential handling instead of introducing a separate application runtime or token-management flow. The tradeoff is a dependency on a working, authenticated `gh` in the shell service's environment and on Omarchy's native plugin APIs; installation documentation must make those requirements clear.

## Considered alternatives

- **Native QML with direct API authentication:** avoids the CLI dependency but requires additional credential setup and storage ownership. That cost is unnecessary for the agreed single-account scope.
- **A standalone web or desktop application:** introduces a separate runtime and integration surface where the native plugin already provides the required UI and lifecycle.
- **Fork an existing plugin wholesale:** existing plugins provide useful contribution-grid and work-query references, but also contain notification mutations or multi-provider machinery outside this project. Reuse suitable pieces selectively and retain their license notices. Notification mutations were later allowed in a limited form by [ADR 0002](0002-notification-inbox-mutations.md).

## Consequences

Credentials remain managed by `gh`; the plugin neither extracts nor stores tokens. API requests must use asynchronous argument-array process calls and preserve account isolation, error handling, and rate-limit behavior.

Compatibility is initially verified against Omarchy 4.0.6's native bar. Supporting replacement bars or other desktop shells would require a separate decision.
