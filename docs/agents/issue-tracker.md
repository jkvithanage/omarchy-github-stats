# Issue tracker: GitHub

Issues and specs live in GitHub Issues for `jkvithanage/omarchy-github-stats`:
https://github.com/jkvithanage/omarchy-github-stats/issues

Use the `gh` CLI. Infer the repository from `origin` when available; otherwise explicitly target `jkvithanage/omarchy-github-stats` with `--repo` on issue commands.

## Conventions

- Publish a spec or ticket as a GitHub issue.
- Fetch the referenced issue's title, body, labels, and comments before working on it.
- Use `--body-file` for multiline issue bodies and comments.
- Apply triage roles using `docs/agents/triage-labels.md`.
- Link child issues with native GitHub sub-issues when available; otherwise put `Part of #<parent>` at the top of each child and list children in the parent.
- Record blockers using native GitHub issue dependencies when available; otherwise put `Blocked by: #<number>, #<number>` near the top of the issue. A ticket is unblocked when every blocker is closed.

## Pull requests as a triage surface

**PRs as a request surface: no.**

## Wayfinding operations

- Map: one issue labelled `wayfinder:map`, containing Notes / Decisions-so-far / Fog.
- Children: one issue per ticket, linked to the map. Use `wayfinder:<type>` labels for `research`, `prototype`, `grilling`, or `task`.
- Frontier: open, unblocked, unassigned children; first in map order wins.
- Claim: assign the ticket to the driving developer before starting work.
- Resolve: comment with the answer, close the ticket, then append a gist and link to the map's Decisions-so-far.
