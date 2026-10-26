# V1 verification — 2026-10-26

This record distinguishes automated native checks from physical-input checks. It does not claim the unverified items below passed.

## Target environment and installation

- Omarchy `4.0.6-1`, native `omarchy.bar`, Quickshell `0.3.2` (Omarchy revision `2b4501a282689792b62e94f3fb30d8f512324fe6`), Qt `6.12.0`.
- Installed validator: `/usr/share/omarchy/bin/omarchy-plugin-validate`. Qt tools: `/usr/lib/qt6/bin/qmllint` and `/usr/lib/qt6/bin/qmltestrunner`.
- `omarchy plugin list --json` reports `omarchy-github-stats` enabled with `bar-widget` and `service` kinds. The existing development installation is a symlink to this checkout; no installation or bar-layout changes were needed.
- A fresh remote clone at integration commit `cdd8c6de29f03009bc42d038ad53644cde533a95` passed `make check` and manifest validation from a temporary directory. This verifies tracked-file packaging; the clone/add CLI was not run over the occupied installed plugin path.
- The live Quickshell environment resolves `gh` through its session PATH. Running there reported `gh 2.103.2` and successful authenticated GraphQL viewer access. Only version/success values were recorded, not credentials or account responses.
- This host has one physical display. Sharing is verified with two native widget consumers, not two physical monitors.

## Automated evidence

`make check` passed: 23 service/model fixtures, Qt JavaScript runtime and heatmap keyboard cases, QML lint, and manifest validation. QML lint reports dynamic host/theme-property and process environment-map warnings; the native run exercises those bindings. No claim is made that lint is warning-free.

The native harness imports the real installed `qs.Ui` and `qs.Commons` components through temporary import links. The offscreen Qt keyboard cases use a small theme fixture because the Quickshell plugin is unavailable inside `qmltestrunner`.

| Behavior | Evidence and result |
| --- | --- |
| Native widget/popup and shared service | `make smoke`: two widgets consume the same service and coalesce overlapping refreshes. Passed. |
| Navigation and Stats views | All three tabs, seven-/thirty-day/annual layouts, period retention across tabs, reset on reopen, focus details, annual horizontal scrolling, and a 220×160 capped popup. Passed. |
| Repository snapshots | Native two-page fixture displays Stars and language shares; service fixtures cover repository/language pagination, scope, ranking, Other, no bytes, and interrupted scans. Passed. |
| Work previews and links | Both native tabs display category totals/previews. A reusable list probe verifies emitted item and View all URLs without launching a browser. Service fixtures verify direct/team search filters, overlap badges, drafts/private data, PR exclusion from issues, ordering, ten-row limits, and totals beyond retrieval caps. Passed. |
| Manual Refresh control | Native harness activates the actual Refresh button, waits for a new complete refresh, and checks updated data. Passed. |
| Failed follow-up refresh | Native `stale` mode first loads all sections, then fails the next refresh. Data and each section's original timestamp remain, with stale flags. Passed. |
| Authentication/network/rate limit/timeout | Native failure modes show unavailable data honestly; the timeout kills an actual stalled process after thirty seconds. Fixtures also cover nonfunctional `gh`, permission errors, retry guidance, and manual-trigger backoff. Passed. |
| UTC/account/concurrency invariants | Fixtures cover midnight/month/year/leap transitions, common chart/summary bounds, zero dates, stable levels, account changes/auth loss, old-result rejection, coalescing, and section freshness. Passed. |
| Theme and accessibility mechanics | Native theme bindings change live, focusable controls expose labels, focused details remain available in a bounded tooltip, and focus scrolls work links into view. Offscreen tests send arrow keys through all heatmap layouts. Passed. |
| Escape/native dismissal callback | Native Escape shortcut and the host owner's dismissal callback are exercised. Passed; this does not establish physical pointer outside-click behavior. |

The exact generated PR GraphQL query was also accepted by GitHub without errors. Fixture tests remain the evidence for non-empty/direct/team/private cases; an empty live search does not prove those cases.

All six native modes passed: `success`, `stale`, `auth`, `network`, `rate`, `hang`. The fixture process never contacts GitHub. Private production account data is not written by these tests.

## Remaining manual evidence

### Follow-up on 2026-10-27

An isolated popup using the unchanged production widget and fixture account data was inspected on the native compositor. Its seven UTC dates, visible counts, activity summaries, repository snapshots, layout, and focus outline rendered visibly. Native virtual-pointer movement over the first tile selected `2026-10-20` in the date-detail state. This adds visual and hover-path evidence; it does not establish physical keyboard or pointer-button behavior.

Injected keyboard and click events did not reliably activate the fixture controls. A temporary focus-capture experiment also failed to establish a valid grabbing popup, so it was discarded without changing production code. These probe results do not establish a widget defect or a passed keyboard/dismissal check. The available computer-use interface exposes browser tabs but no native desktop apps, so the remaining physical-input checks still require desktop observations. Temporary probes were stopped and desktop-region captures removed.

The physical-check request is pending. Issue #7 remains open and `ready-for-human`; no pending acceptance item has been marked passed.

The following are **not verified** by this run:

- Physical Tab/arrow traversal and visible focus in the live installed bar, plus screen-reader announcement quality.
- Physical hover/focus date/count inspection and pointer outside-click dismissal. Synthetic focus, tooltips, Escape, and callback tests cover their mechanics but do not replace physical input.
- Actual external-browser launch by clicking an installed work link. Emitted URLs and filters are tested, and widget wiring uses `Qt.openUrlExternally`; no real work link was clicked during automation.
- Two physical monitors. Two consumers share one service in the native harness, but only one display is attached.
- A clean interactive `omarchy plugin add` trust/placement flow. Existing enablement, a clean clone, and validator/runtime checks are established; the already occupied installation was preserved.

For a release or host upgrade, open the installed widget, Tab through tabs/periods/Refresh/work links, inspect focused and hovered tile details, check visible focus and screen-reader labels, activate one known work link, press Escape, reopen and click outside, and repeat on a second monitor when available. Recheck small-screen scrolling and a live theme change. Record observations and versions before marking these physical checks passed.

## Source and permission audit

Tickets #2–#7 introduce no copied upstream implementation or helper dependencies. Native host components are imported; credentials remain owned by `gh`. No GitHub mutations, interactive shell login, token extraction/storage, private-response logging, or account-data persistence were added. Substantial future reuse from `omarchy-ghstats` must preserve its MIT notice.
