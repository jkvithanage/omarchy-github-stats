# Omarchy GitHub Stats

A native Omarchy bar plugin for personal GitHub contributions, pull requests, and issues.

The bar shows a GitHub icon and today's contribution count. Its popup has three tabs: **Stats**, **PRs**, and **Issues**. Stats provides contribution heatmaps for the last 7 days, 30 days, and 12 months, with activity summaries, stars, and repository languages beneath the chart.

## Project status

The v1 design is agreed. This directory currently contains planning documents; the plugin has not been implemented and is not ready to install.

## Documentation

- [Specification](SPEC.md): behavior, data definitions, architecture, and acceptance criteria.
- [Glossary](GLOSSARY.md): the project's domain vocabulary.
- [Architecture decision](docs/adr/0001-native-omarchy-and-gh.md): native Quickshell UI and GitHub CLI integration.

## Planned platform

- Omarchy 4's native Quickshell bar, with initial verification against Omarchy 4.0.6.
- QML/JavaScript using Omarchy's popup and theme components.
- GitHub CLI (`gh`) for authenticated access to one `github.com` account.

The plugin will read GitHub data and open browser links. Credentials remain managed by `gh`.

## Existing work

[omarchy-ghstats](https://github.com/srineshr1/omarchy-ghstats) provides a useful native contribution-grid reference. Any substantial code reused from that project must retain its MIT copyright and permission notice.
