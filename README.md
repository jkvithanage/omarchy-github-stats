# Omarchy GitHub Stats

A native Omarchy bar plugin for personal GitHub contributions, pull requests, and issues. The bar shows a GitHub icon and today's UTC contribution count; its popup has **Stats**, **PRs**, and **Issues** tabs.

## Features and status

PRs and Issues tabs show full open-work totals from their two disjoint categories, independent of the Stats period. Large counts use k/m abbreviations with exact totals in accessible names and tooltips. `—` means unavailable; `*` marks saved stale totals. Work tabs summarize review requests or assignments from other authors without double-counting authored overlaps. On narrow screens, counts move below their tab labels.

V1 features and verification documentation are complete. See the [verification record](docs/verification.md) for tested versions, automated evidence, maintainer-confirmed desktop checks, and remaining screen-reader, multi-monitor, and clean-install verification limits.

- **Stats:** 7 days, 30 days, and 12 months, with Sunday-first contribution heatmaps, theme colors, hover/focus date and count details, and separate contribution, commit contribution, authored PR, and authored issue summaries. The annual chart scrolls horizontally with month/year labels. Reopening resets to Stats and 7 days; switching tabs retains the period during that opening.

Keyboard users enter a contribution heatmap with Tab, browse dates with arrow keys, and leave with Tab or Shift+Tab. A new period starts at the latest available date; re-entry remembers the focused date, and refreshes preserve it while it remains in the period. Padding is skipped and focused dates scroll into view.

A small underline marks today's incomplete UTC date, independently of the keyboard-focus border. The Less-to-More legend follows GitHub's relative contribution levels. Annual weekday labels remain fixed while dates scroll; **Latest** returns to the newest dates without fetching data or moving focus.
- **Current repository snapshots:** Stars and the top five Repository languages plus Other, from complete repository/language pagination. The scope is personally owned public and accessible private repositories, excluding forks and including archives. Language shares describe repository code bytes, independently of the Stats period.

Stats leads with the selected-period contribution total, followed by its date range and heatmap. Commit contributions, authored PRs and authored issues remain supporting metrics; current Repository snapshots are visually secondary and independent of that period.
- **Open work:** authored PRs, pending direct/team review requests from other authors, authored issues, and assignments from other authors. Each category has API totals, up to ten recently updated rows, role/private/draft labels where relevant, linked titles and View all browser links. Update times use relative labels for the last week and short local dates for older work; hover or focus the update label for the exact local timestamp. Bounded overlap lookups provide secondary-role badges on authored previews without adding to totals.

## Requirements

- Omarchy 4's native Quickshell bar; verified against Omarchy **4.0.6-1** and Quickshell **0.3.2**.
- A working, authenticated GitHub CLI (`gh`) on the **running shell process's PATH**. Terminal aliases or interactive version-manager setup alone may not apply to that process.
- One effective account on `github.com`. Other Git hosts and in-widget account switching are outside v1.

Authenticate in a terminal, then check the effective account without printing tokens:

```sh
gh --version
gh auth login --hostname github.com
gh api --hostname github.com graphql -f 'query=query { viewer { login } }' --jq .data.viewer.login
```

Environment credentials supported by `gh` take precedence over its stored account. The plugin uses that effective identity and never starts an interactive login in the shell.

## Install and enable

```sh
omarchy plugin add https://github.com/jkvithanage/omarchy-github-stats --enable
```

The host clones and validates the plugin, then enables its widget and shared service. If installed without enablement, or to place it in the right bar section:

```sh
omarchy plugin enable omarchy-github-stats --section right
omarchy plugin list
```

Use the native `omarchy.bar`. Replacement bars can withhold the companion service from third-party widgets. Normal git-managed installations can be updated with `omarchy plugin update omarchy-github-stats`; review the offered changes. Do not use that updater on a development checkout with uncommitted work.

For local development, validate with `omarchy plugin validate .`, then place or symlink the checkout at `~/.config/omarchy/plugins/omarchy-github-stats` when that path is not already occupied. Run `omarchy shell shell rescanPlugins`, then enable it as above. Saved plugin code hot-reloads. The host owns one service; monitor widgets consume that service rather than fetching separately.

## Refresh and recovery

Refresh runs at startup, every fifteen minutes, after UTC midnight, and from the popup's **Refresh** button. Period switching uses cached data. The bar displays `—` for an unknown count and `0` for a successful zero. Today remains incomplete until the next UTC midnight.

The footer describes the visible section (Activity, PRs or Issues) with a relative update time; hover or focus it for exact local timestamps for every section. Repository freshness remains independent of Activity. Initial loading, refreshing saved work, and showing saved work after failure have distinct messages. Transient failures retain previous complete sections, marked stale with their original timestamps. An interrupted repository scan never publishes partial totals. Authentication loss or an observed account change clears prior-account data. Manual refresh respects rate-limit waits too.

For authentication errors, run `gh auth status --hostname github.com`, recover with `gh auth login --hostname github.com`, then press Refresh. If the widget reports missing/nonfunctional `gh` while terminal commands work, check the shell session's PATH and noninteractive version-manager setup. After correcting session startup environment, use `omarchy restart shell` to let the shell inherit it. Network, permission, timeout, rate-limit, and incomplete-response states have separate guidance in the popup; failures are never shown as zero activity.

## Data and access

The plugin is read-only: it fetches GitHub data and opens browser links. Credentials remain managed by `gh`; the plugin neither extracts nor stores tokens. Account responses stay in memory and are not logged or persisted by the plugin. The widget requests no additional permissions or separate credential service.

Contribution counts follow GitHub's eligibility and visibility rules. Accessible private activity and repository/work coverage depend on the effective credentials and GitHub's rules; the widget does not promise private-data completeness. Authored activity summaries include eligible creations that have since closed or merged. Open-work previews are independent of the selected period, and View all delegates full-list browsing to GitHub.

## Verification and development

```sh
make check
make smoke
```

`make check` runs service fixtures, Qt model/heatmap keyboard tests, QML lint, and the installed manifest validator. Development checks require Node.js, Python 3, Make, and Qt 6 tooling; the installed plugin only requires Omarchy/Quickshell and `gh`. Tool paths default to `/usr/lib/qt6/bin` and `/usr/share/omarchy`; override `QT_BIN` or `OMARCHY_PATH` for a different installation. Offscreen keyboard tests substitute the host theme boundary; native smoke uses installed Omarchy components.

`make smoke` requires a Hyprland session. It briefly opens an isolated test bar/popup with two consumers and fixture `gh` responses, and leaves the installed bar configuration unchanged. Six modes cover successful loading/manual refresh, stale refresh, authentication, network, rate limits, and a real thirty-second process timeout. Fixtures contain no account data and make no network calls. See [verification details and manual checks](docs/verification.md).

## Project documentation

- [Specification](SPEC.md): agreed behavior and acceptance criteria.
- [Glossary](GLOSSARY.md): domain definitions.
- [Architecture decision](docs/adr/0001-native-omarchy-and-gh.md): native QML/Quickshell and GitHub CLI.

[omarchy-ghstats](https://github.com/srineshr1/omarchy-ghstats) is a contribution-grid reference. No upstream implementation was copied for tickets #2–#7. Any future substantial reuse must retain its MIT copyright and permission notice; notification mutations and helper dependencies are outside this plugin's scope.
