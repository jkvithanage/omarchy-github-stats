# Omarchy GitHub Stats — specification

Status: v1 features and verification documentation are complete. The v2 notifications **Inbox** is an agreed design that is not yet implemented ([#35](https://github.com/jkvithanage/omarchy-github-stats/issues/35)). Installation guidance, automated evidence, and maintainer-confirmed desktop checks are recorded in [the verification report](docs/verification.md), including remaining screen-reader, multi-monitor, and clean-install verification limits.

## Purpose and boundaries

Build a public Omarchy plugin that makes personal GitHub activity visible from the bar and provides quick browser access to open PRs and issues.

The project and repository name are **Omarchy GitHub Stats** and **`omarchy-github-stats`**. V1 targets Omarchy 4's native Quickshell bar, initially verified against Omarchy 4.0.6. It uses one effective `github.com` account through GitHub CLI (`gh`), including private data the effective credentials permit it to access.

V1 is read-only. V2 adds the notifications Inbox, whose notification actions are the only GitHub mutations: marking read, Done, Unsubscribe, and Subscribe ([ADR 0002](docs/adr/0002-notification-inbox-mutations.md)). The plugin does not create, edit, merge, close, assign, or otherwise mutate PRs, issues, repositories, or other GitHub resources. It does not include account switching, other Git hosts, historical year selection, saved notifications, or an in-widget replacement for GitHub's full work lists or notification views.

## Bar and popup

- Show a GitHub icon and today's contribution count in the bar. Today follows the GitHub contribution calendar's UTC date boundary.
- Show an unread dot beside the count while the Inbox's unread count is known and above zero. Its accessible name and tooltip give the exact unread count.
- Clicking the widget toggles an anchored native Omarchy popup.
- Provide exactly four primary tabs: **Stats**, **PRs**, **Issues**, and **Inbox**.
- Each popup opening starts on Stats with **7 days** selected. Switching away from Stats and back during that opening retains the selected period.
- Use Omarchy's theme colors, typography, popup positioning, screen fitting, and dismissal behavior.
- Keep content usable on smaller screens through constrained layout and scrolling where needed.
- Support keyboard navigation, visible focus, meaningful accessible labels, and Escape dismissal. Chart counts must be available without relying on color alone.

## Stats

### Periods and contribution heatmaps

Offer **7 days**, **30 days**, and **12 months**. Each period ends today; today is an incomplete day until the next UTC midnight.

| Period | Layout | Date coverage |
| --- | --- | --- |
| 7 days | One chronological row of seven tiles | Today and the previous six dates |
| 30 days | Seven weekday columns with chronological week rows | Today and the previous twenty-nine dates |
| 12 months | GitHub-style weekday rows and week columns | A rolling twelve-month span ending today |

Use Sunday-first weekday alignment for calendar grids. Pad incomplete weeks with empty layout slots, not zero-contribution dates. Show date labels appropriate to the scale, including month labels on the annual view.

For the annual range, start at UTC midnight on the date immediately after the same date in the previous year; clamp February 29 to February 28 when finding that previous-year date. This produces 365 or 366 included dates. Query through the current instant, and use the same bounds for its summaries.

Fetch an annual contribution calendar and preserve its returned dates, counts, and contribution levels. Slice that calendar for shorter views so switching periods does not change a day's color intensity. Map levels to neutral and theme-accent shades; do not use the API's fixed colors over the active Omarchy theme.

Each tile exposes its full date and contribution count on hover or keyboard focus. The contribution total covers the displayed dates. Calendar counts are GitHub contributions, not commits alone.

Each populated heatmap has one sequential Tab stop. First entry for a selected period focuses today when available, otherwise the latest available date. Arrow keys follow the chart arrangement, skip padding and stop at boundaries; Tab/Shift+Tab leave the chart. Re-entry remembers the browsed date, including across refreshes while it remains available. Missing/empty charts add no Tab stop; rollover or removed coverage falls back to the latest available date.

Mark today's incomplete UTC date with an underline below its colored tile, distinct from the keyboard-focus border, and identify it in accessible details. Include a compact Less-to-More legend using the same relative contribution levels and theme colors, without fixed-count threshold claims. Annual weekday labels occupy a stationary gutter outside the scrolling dates/month labels. Provide a keyboard-accessible Latest action beneath the annual chart that reveals newest dates without fetching data or moving focus.

### Activity summaries

Lead Stats with a prominent selected-period contribution total above the chart and an explicit visible period/date association. Below the chart, show the supporting activity metrics, with precise accessible meanings:

- Commit contributions in the selected period.
- PRs authored in the selected period.
- Issues authored in the selected period.

Do not repeat the contribution total as a peer-level supporting metric. Keep current repository snapshots visually secondary using native typography, preserving original heatmap sizes and the narrow adaptive popup. Successful zero, loading, unavailable and stale data remain distinct.

Use the corresponding GitHub contribution-collection fields for commit, PR, and issue summaries. Do not infer these from total calendar activity or from open work queues. In particular, PR and issue activity includes eligible creations that have since closed or merged.

Use UTC midnight at the start of the selected range and the current instant as its bounds. Keep fetched chart data and summaries on a common refresh time. Do not present a failed or incomplete request as a zero.

### Repository snapshots

Show these beneath the period activity summaries, labeled as current repository snapshots:

- **Stars**: current stars summed across the repository scope.
- **Repository languages**: the top five languages by aggregated code bytes, plus **Other** for all remaining languages. Percentages use all reported language bytes as the denominator. Omit Other when there is no remainder.

The repository scope includes personally owned public and accessible private repositories, excluding forks and organization-owned repositories. Include archived repositories; do not add an unrequested archive filter. The scope applies to these snapshots, not to contributions or work queues, which can include activity in other owners' repositories.

Paginate all repositories and language connections needed for complete aggregates. Do not label a truncated sample as an account-wide total. Where no language bytes exist, show an empty state rather than fabricated percentages.

## PR and issue tabs

### PRs

Include open PRs authored by the account and open PRs awaiting review from the account or one of its teams. Include drafts where they match these conditions and identify them visibly. Review requests end when GitHub no longer reports them as pending.

### Issues

Include open issues authored by or assigned to the account. Exclude PRs from issue results.

### List presentation and overlap

- Group by authored work and review-requested or assigned work. Place an item matching both groups in the authored group and retain its other role as a badge.
- Make secondary group labels explicit: review requests or assignments from other authors. This allows disjoint category totals without double-counting.
- Show the ten most recently updated matches in each disjoint category, ordered by update time descending.
- Display each item's title, repository, number, role, and update time. Mark private repositories and draft PRs where relevant.
- Show full category totals separately from the number of preview rows. Use API totals, not preview lengths.
- Open individual items through keyboard-operable linked titles with visible hover/focus affordances. Keep repository/number and role/private/draft details; omit a redundant separate Open button. Update times use relative labels for recent work and concise local dates for older work, with exact local timestamps available on hover/focus and through accessible descriptions. Labels update while visible without fetching data. Provide a **View all** link for each category, preserving its open-state, account-role, and overlap-exclusion filters.
- Provide explicit empty, initial-loading, refreshing-saved-data, and failed states. Identify retained work as saved data after a failed refresh. Do not show a completed empty list while its request is still loading. Footer freshness follows the active tab's section with concise relative wording and exact original local timestamps on hover/focus and in accessible descriptions. Stats labels Activity freshness and exposes Repository freshness independently.

Work lists are independent of the selected Stats period. Selecting 7 days does not hide an older open issue or PR.

Completed empty categories explicitly name authored PRs, pending review requests from other authors, authored issues or issues from other authors assigned to the account. Suppress completed-empty messages during loading, refresh and failure/stale states. Authentication recovery offers a fixed-command clipboard action with visible and accessible confirmation, without starting interactive login or handling credentials. Rate-limit guidance shows remaining wait and the exact local retry time; the existing Refresh deadline remains authoritative. Permission and incomplete-response guidance include a practical next step.

PRs and Issues tab counts sum their disjoint category API totals, not preview lengths. Abbreviate large counts only in visible labels and retain exact totals in accessible names and tooltips. Distinguish unknown totals from successful zero and mark retained stale totals. Counts may sit below tab labels under narrow screen caps. Each work tab summarizes its secondary category explicitly as review requests or assignments from other authors, preserving authored-first grouping and overlap badges without new API requests.

## Inbox

The Inbox tab lists the account's notifications not marked done, read and unread, newest first, with unread notifications emphasized. Load the fifty most recent notifications in one page and provide a **View all** link to `https://github.com/notifications`. Saved and Done views, mark-as-unread, filters, grouping, and saving notifications stay on github.com; GitHub's API does not expose saving.

### Rows

- Each row shows an unread marker, the subject type (PR, issue, release, discussion, CI, or other), a linked title, the repository and number where applicable, the notification reason, and a relative update time with the exact local time on hover/focus and in accessible descriptions.
- Opening a title opens the subject's web page and marks the notification read. PRs, issues, releases, and discussions open their github.com pages; CI notifications open the repository's Actions page; other subjects fall back to the repository page.
- Each row has always-visible, keyboard-operable **Done** and **Unsubscribe** actions with tooltips and accessible names. After Unsubscribe, the row offers **Subscribe** to reverse it, based on actions taken in the current session. Do not offer Ignore.
- Include CI notifications like other subjects.

### Selection and bulk actions

Every row has a checkbox, and a header checkbox selects all visible rows. While any row is selected, an action bar shows the selected count with **Done** and **Unsubscribe**. Bulk actions apply to selected visible rows only, issue one request per notification with bounded concurrency, and report failures per row.

### Applying actions

Apply Done, Unsubscribe, Subscribe, and mark-read immediately without confirmation. A failed request restores only the affected row and identifies the failure on it. A refresh that arrives while an action is pending must not restore a row the action removed. Done cannot be undone; GitHub returns the notification to the Inbox on new thread activity.

The Inbox follows the work lists' empty, initial-loading, refreshing-saved-data, failed, and footer-freshness patterns.

## Architecture and data ownership

Use QML/JavaScript and Omarchy's existing popup and theme components. No web server, Electron runtime, database, or custom credential service is required.

Declare a native bar widget and a host-managed service in the plugin manifest. Use `omarchy-github-stats` as the plugin ID; it does not use Omarchy's reserved `omarchy.*` namespace. Match the installed host's manifest schema and entrypoint contract.

The service owns account identity, API requests, refresh scheduling, pagination, shared data, and freshness/error state. All monitor widgets consume that one service. Views own presentation and popup-local navigation. Keep date-window, aggregation, and deduplication logic independently testable.

Run `gh api` requests asynchronously using Quickshell process APIs and argument arrays. Explicitly target `github.com`; let `gh` resolve its effective credentials. Do not extract tokens, store credentials in widget settings, interpolate request values into shell command strings, or log private responses and credentials.

Include the effective account identity in data requests. Discard results from superseded refreshes, and prevent results from different identities from being combined. Clear cached account data when identity changes or authentication is lost. V1 has no widget-specific account selector.

Use GitHub GraphQL for the contribution calendar, period summaries, repository data, and work searches. Prefer four disjoint work searches—authored PRs, review requests excluding authored PRs, authored issues, and assignments excluding authored issues—rather than relying on uncertain union-count behavior. Review coverage must include team requests, not only direct user requests.

Only preview ten rows per category; full-list pagination belongs to the browser in v1. Respect API limits and do not confuse the search retrieval cap with a complete downloadable result set. Repository aggregates, unlike work previews, require complete pagination.

Use the GitHub REST notifications API for the Inbox and its actions; GraphQL does not expose notifications. Notification requests use the same `gh api` argument-array, identity-isolation, error-classification, and rate-limit rules as other requests. Validate thread identifiers before placing them in request paths. Notification polling and actions run independently of the sequential activity refresh so neither blocks or reorders the other. These endpoints require a classic or OAuth token with `notifications` or `repo` scope; fine-grained personal access tokens are unsupported.

Selectively reuse suitable native grid or panel code from [omarchy-ghstats](https://github.com/srineshr1/omarchy-ghstats). Preserve its MIT copyright and permission notice for copied substantial code. Do not import its notification code or add its helper dependencies merely to reuse the grid.

## Refresh and failure behavior

- Fetch at service startup, every fifteen minutes, on manual Refresh, and after a UTC day rollover.
- Poll the Inbox at service startup, on manual Refresh, and at the interval GitHub's `X-Poll-Interval` requests (at least sixty seconds). Send `If-Modified-Since` with the last `Last-Modified` value; treat a `304 Not Modified` response as current data, not a failure.
- Fetch all three periods' summaries with the calendar so changing periods does not require a new network request after a successful refresh.
- Coalesce overlapping refresh triggers. Use bounded asynchronous requests so a stalled process cannot leave refreshing active indefinitely.
- Keep data only in memory; do not persist private account data to disk.
- Show the time of the last successful update. Preserve previously successful sections on transient failure and identify them as stale. A section's failed refresh must not mark its old value as freshly updated.
- When the cached calendar does not cover the new UTC date, do not relabel yesterday's count as today's. Request fresh data and show today's count as unavailable until known.
- Distinguish missing or nonfunctional `gh`, missing authentication, insufficient permissions, network failure, rate limiting, and valid empty results.
- Give concise setup guidance for `gh auth login` when authentication is needed. Do not start an interactive login inside the shared shell process.
- Respect GitHub's rate-limit reset or retry guidance and avoid tight automatic retries. Retain useful existing data while waiting.
- Only request permissions needed by the agreed features. Do not promise private-data completeness beyond the effective credentials and GitHub visibility rules.

## Acceptance and verification

Implementation is complete when the following are demonstrated:

1. The manifest validates and the native bar widget loads on the target Omarchy shell with working popup, tabs, browser links, and refresh.
2. All periods show the correct included dates and summaries. Verify UTC rollover, month/year transitions, leap dates, partial weeks, zero-activity days, and stable tile levels across period switches.
3. Repository fixtures spanning multiple pages produce correct owner/fork filtering, star totals, language ranking, percentages, and Other. Interrupted pagination cannot publish a partial aggregate as complete.
4. Work fixtures demonstrate authored, assigned, direct-review, and team-review coverage; deduplication; draft handling; ordering; ten-row previews; accurate category totals; and matching View all filters.
5. Missing `gh`, authentication loss, account changes, partial failures, timeout, rate limiting, empty data, and stale refreshes produce honest states without leaking prior-account data or replacing failures with zeros.
6. Multiple monitor widgets use one refresh service. Overlapping refreshes do not launch duplicate work or allow older results to overwrite newer data.
7. A manual native-shell check covers keyboard access, focus, hover/focus tile details, Escape/outside-click dismissal, small-screen fitting, and live theme changes.
8. Inbox fixtures demonstrate unread and read rows, link mapping including CI notifications, mark-read on open, per-row and bulk Done/Unsubscribe/Subscribe, per-row rollback on partial failure, a refresh racing a pending action, `304` polling, poll-interval and rate-limit handling, and clearing on account change.

Use focused fixture-based tests for model and service behavior, QML linting, the Omarchy plugin manifest validator, and a native-shell smoke test. The installed environment provides Qt's `qmllint` and `qmltestrunner` under `/usr/lib/qt6/bin`; verify tool and import paths during implementation.

## References

- [Domain glossary](GLOSSARY.md)
- [Architecture decision](docs/adr/0001-native-omarchy-and-gh.md)
- [Quickshell asynchronous process API](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/Process)
- [GitHub CLI authentication](https://cli.github.com/manual/gh_auth_login)
- [GitHub CLI API requests](https://cli.github.com/manual/gh_api)
- [GitHub GraphQL objects](https://docs.github.com/en/graphql/reference/objects)
- [GitHub contribution timestamps](https://docs.github.com/en/account-and-profile/reference/profile-contributions-reference)
- [GitHub issue and PR search filters](https://docs.github.com/en/search-github/searching-on-github/searching-issues-and-pull-requests)
- [GitHub GraphQL pagination](https://docs.github.com/en/graphql/guides/using-pagination-in-the-graphql-api)
- [Notification Inbox decision](docs/adr/0002-notification-inbox-mutations.md)
- [GitHub REST notifications](https://docs.github.com/en/rest/activity/notifications)
