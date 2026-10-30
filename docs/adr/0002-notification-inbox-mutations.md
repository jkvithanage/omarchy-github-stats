---
status: accepted
---

# Allow notification-only mutations for the Inbox

Add a notifications Inbox that can mark notifications read, mark them done, and unsubscribe or subscribe threads. These are the plugin's only GitHub mutations; PRs, issues, repositories, and other resources stay read-only. Requests use GitHub's REST notifications API through asynchronous `gh api` argument-array calls, because GraphQL does not expose notifications. Actions apply immediately and roll back only the affected row on failure. Saving notifications is not supported because the API does not expose it.

This keeps ADR 0001's ownership model (credentials stay with `gh`, one host-managed service owns requests and state) and reverses only its read-only scope. Users get GitHub's everyday triage actions from the bar, and the remaining inbox features (Saved and Done views, mark-as-unread, filters) stay on github.com instead of being approximated.

## Considered alternatives

- **Stay read-only:** list notifications without actions. Rejected because triage is the reason to show notifications in the bar.
- **A separate notifications plugin:** keeps this plugin read-only, but duplicates account identity, polling, error, and rate-limit handling that the existing service already owns.
- **An in-plugin saved list:** imitates GitHub's Save, but would not match the account's real Saved list and would be lost on restart, since account data stays in memory only.

## Consequences

The plugin now changes account state. Like GitHub, the Inbox asks for no confirmation, so Done is recoverable only through new thread activity. Notification endpoints require a classic or OAuth token with `notifications` or `repo` scope; fine-grained personal access tokens and GitHub App tokens are unsupported. Notifications poll independently of the fifteen-minute activity refresh, honoring GitHub's `X-Poll-Interval` and conditional `Last-Modified` requests, whose `304` responses `gh` reports as a non-zero exit that must not be treated as a failure. Bulk Done has no bulk endpoint and costs one request per notification.
