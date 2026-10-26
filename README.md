# Omarchy GitHub Stats

A native Omarchy bar plugin for personal GitHub contributions, pull requests, and issues.

The bar shows a GitHub icon and today's contribution count. Its popup has three tabs: **Stats**, **PRs**, and **Issues**. The [v1 specification](SPEC.md) describes the planned period heatmaps, activity summaries, repository snapshots, and work previews.

## Project status

The bar shows today's UTC contribution count. Stats offers 7 days, 30 days, and 12 months, with Sunday-first calendar layouts, themed contribution levels, hover/keyboard date details, and separate contribution, commit contribution, authored PR, and authored issue summaries. The annual chart scrolls horizontally with month/year labels. Switching periods uses the same cached snapshot; reopening the popup resets to 7 days. Current repository snapshots show Stars and the top five Repository languages plus Other, using complete repository/language pagination across personally owned public and accessible private repositories, excluding forks and including archives. The PRs tab shows open authored PRs and pending direct/team review requests from other authors, with disjoint API totals, ten-row previews, draft/private labels, and browser links. A bounded overlap lookup supplies review badges for authored previews without contributing to totals. Each section retains its previous complete result as stale on failure. Issue previews are not implemented yet.

## Installation

Requires Omarchy 4's native Quickshell bar and a working GitHub CLI (`gh`) on the **shell process's PATH**. Authenticate outside the shell with `gh auth login --hostname github.com`. Environment credentials supported by `gh` take precedence over its stored account; the plugin uses that effective account. It never reads or stores tokens and keeps account responses only in memory.

From this checkout, validate the manifest with `omarchy plugin validate .`. After the implementation is available in the remote repository, install it with:

```sh
omarchy plugin add https://github.com/jkvithanage/omarchy-github-stats --enable
```

For local development, place this checkout at `~/.config/omarchy/plugins/omarchy-github-stats`, run `omarchy-shell shell rescanPlugins`, then `omarchy plugin enable omarchy-github-stats`. The host creates one service for all monitors; widgets only consume it. Use the native bar; replacement bars may intentionally withhold third-party service access.

The bar uses `—` when today's count is unknown. A successful zero is shown as `0`. Refresh runs at startup, every fifteen minutes, after UTC midnight, and from the popup. Transient errors retain previously successful data with a stale label and its original update time. Authentication loss and account changes clear old account data. Rate-limit waits apply to manual refresh too.

GitHub contribution counts follow GitHub's visibility and eligibility rules; accessible private activity depends on the effective credentials. No additional permissions are requested by the plugin, and login is never launched interactively inside the shell.

## Documentation

- [Specification](SPEC.md): behavior, data definitions, architecture, and acceptance criteria.
- [Glossary](GLOSSARY.md): the project's domain vocabulary.
- [Architecture decision](docs/adr/0001-native-omarchy-and-gh.md): native Quickshell UI and GitHub CLI integration.

## Platform

- Omarchy 4's native Quickshell bar, with initial verification against Omarchy 4.0.6.
- QML/JavaScript using Omarchy's popup and theme components.
- GitHub CLI (`gh`) for authenticated access to one `github.com` account.

The plugin will read GitHub data and open browser links. Credentials remain managed by `gh`.

## Verification

Run `make check` for the service fixtures, Qt model and heatmap keyboard tests, QML lint, and the installed Omarchy manifest validator. The offscreen heatmap tests substitute only the host theme boundary; native smoke uses the installed theme components. Development checks use Node.js, Python 3, Make, and Qt 6 tooling; the installed plugin only needs Omarchy/Quickshell and `gh`. QML lint may report dynamic host-property and QVariant environment-map warnings; the native smoke test verifies those bindings at runtime.

Run `make smoke` from a Hyprland session for an isolated native widget/popup test with two consumers and fixture `gh` responses, including a real thirty-second process timeout. It checks focus targets, Escape, popup reset, constrained scrolling, theme bindings, and the native dismissal callback. This briefly opens a test bar and popup and leaves the installed bar configuration unchanged. Fixture responses contain no account data and make no network calls.

Initial native compatibility was checked against `omarchy version` 4.0.6-1 and Quickshell 0.3.2. Physical Tab/arrow traversal and pointer outside-click dismissal remain manual verification checks, including when deploying to a new host version.

## Existing work

[omarchy-ghstats](https://github.com/srineshr1/omarchy-ghstats) provides a useful native contribution-grid reference. Any substantial code reused from that project must retain its MIT copyright and permission notice.
