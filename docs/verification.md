# V1 verification — 2026-10-26

This record distinguishes automated native checks, maintainer-reported physical checks, and the remaining unverified items below.

## Stats hierarchy — 2026-10-29 (#22)

Stats leads with a native display-size contribution total and explicit selected-period date heading. Supporting metrics retain precise accessible explanations; the duplicate contribution metric is removed, and the current Repository heading is quieter. The native regression first failed because no primary total existed. Added assertions distinguish successful zero, missing data and initial loading, and check the period association in every Stats view. Existing worst-case six-row month, six language shares, independent stale states, theme changes, native caps and original heatmap-size checks remain in place. Physical screen-reader and screen-edge verification limits are unchanged.

`make check` and all six `make smoke` modes pass. The native fixture now lets focus-grab close/reopen events settle on separate ticks instead of toggling several times in one event. Fixture renders in `/tmp/stats-22-captures` were inspected, including the six-row month, all six language shares and stale guidance. Existing dynamic host/theme lint warnings remain.

## Calendar keyboard entry — 2026-10-29 (#21)

Heatmaps expose one sequential Tab stop, enter at the latest available date for a new period, and retain the browsed date on re-entry and refresh. Arrow keys skip padding and reveal focused dates; removing the remembered date falls back to the latest covered date. An empty chart adds no stop. The initial regression failed when Tab entered the first date rather than the latest. Focused QML coverage exercises forward/backward entry and exit for all periods, refresh replacement, rollover and boundaries. Native tests retain original sizing, constrained scrolling, annual browsing, tooltips and Escape checks. Physical keyboard and screen-reader observation limits remain unchanged.

`make check` passes (23 service fixtures, 19 Qt cases, lint and manifest validation; existing host/theme lint warnings remain), and all six `make smoke` modes pass. Review caught entry-date memory surviving a new weekly popup session; opening now explicitly resets entry, with QML and native close/reopen regressions. The offscreen theme boundary supplies the caption/body-small sizes used by the exercised labels.

## Active-tab freshness — 2026-10-29 (#20)

The footer follows Activity, PRs or Issues and labels stale sections explicitly, using the relative-time presentation from #19. Exact original timestamps for every section remain available on hover/focus. Work-list messages distinguish initial loading, refreshing cached work and showing saved work after failure; redundant stale timestamps below the list were removed. The native regression first failed because PRs inherited Activity's timestamp. Native coverage now supplies deliberately different section times and checks tab changes. `make check` passes (23 service fixtures, 16 Qt cases, lint and manifest validation; existing host/theme warnings remain), and all six `make smoke` modes pass. Existing stale-refresh, repository-only failure, account isolation and retry checks are retained. Physical screen-reader and screen-edge verification limits remain unchanged.

## Linked work titles — 2026-10-29 (#19)

PR and issue titles are now the primary browser links, replacing separate Open buttons. Relative update labels refresh while visible and retain exact local timestamps on hover/focus. Metadata, category totals, badges and View all URLs are preserved. The native title-link regression failed before implementation. `make check` passes (23 service fixtures, 16 Qt cases, lint and manifest validation; existing dynamic host/theme lint warnings remain). `make smoke` passes all six modes, including title URLs, truncated totals, badges and constrained focus reveal. QML tests exercise wrapped-title Return/Space, pointer and accessibility activation, and relative/exact timestamp presentation.

Fixture renders in `/tmp/stats-19-captures` were inspected for compact work rows and preserved metadata. The fixture harness does not launch a real browser. Physical keyboard/browser activation and screen-reader announcement quality remain unverified; the earlier physical/screen-edge limits still apply.

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

## Manual evidence and remaining limits

### Follow-up on 2026-10-27

An isolated popup using the unchanged production widget and fixture account data was inspected on the native compositor. Its seven UTC dates, visible counts, activity summaries, repository snapshots, layout, and focus outline rendered visibly. Native virtual-pointer movement over the first tile selected `2026-10-20` in the date-detail state. This adds visual and hover-path evidence; it does not establish physical keyboard or pointer-button behavior.

Injected keyboard and click events did not reliably activate the fixture controls. A temporary focus-capture experiment also failed to establish a valid grabbing popup, so it was discarded without changing production code. These probe results do not establish a widget defect or a passed keyboard/dismissal check. The available computer-use interface exposes browser tabs but no native desktop apps, so the remaining physical-input checks still require desktop observations. Temporary probes were stopped and desktop-region captures removed.

### Maintainer confirmation on 2026-10-28

In response to the requested installed-widget checks, the maintainer reported: “Seems all good to me”. This records maintainer confirmation of physical Tab/arrow navigation, visible focus, hover/focus date-and-count details, Escape and outside-click dismissal, and browser-link opening. These are reported desktop observations, not additional automated results. No defect was reported and no production code changed.

The v1 implementation and verification documentation are complete with the limitations below recorded. The general confirmation does not establish screen-reader quality, a second physical monitor, or a clean interactive installation.

The following are **not verified** by this run:

- Screen-reader announcement quality. Accessible-label mechanics are tested, but no screen-reader session is recorded.
- Two physical monitors. Two consumers share one service in the native harness, but only one display is attached.
- A clean interactive `omarchy plugin add` trust/placement flow. Existing enablement, a clean clone, and validator/runtime checks are established; the already occupied installation was preserved.

For a release or host upgrade, open the installed widget, Tab through tabs/periods/Refresh/work links, inspect focused and hovered tile details, check visible focus and screen-reader labels, activate one known work link, press Escape, reopen and click outside, and repeat on a second monitor when available. Recheck small-screen scrolling and a live theme change. Record observations and versions before marking these physical checks passed.

## Source and permission audit

Tickets #2–#7 introduce no copied upstream implementation or helper dependencies. Native host components are imported; credentials remain owned by `gh`. No GitHub mutations, interactive shell login, token extraction/storage, private-response logging, or account-data persistence were added. Substantial future reuse from `omarchy-ghstats` must preserve its MIT notice.

## Appearance cleanup — 2026-10-28 (#17)

Specification: [#17](https://github.com/jkvithanage/omarchy-github-stats/issues/17). This follow-up changes presentation only; `Service.qml`, `ServiceModel.js`, the GitHub queries, and the glossary's UTC calendar definition are unchanged.

`make check` passed: all 23 service/model fixtures, 9 Qt test cases including setup/cleanup (4 heatmap behavior cases and the service runtime case), QML lint, and manifest validation. Lint still reports dynamic host/theme-property warnings; it is not warning-free. `git diff --check` passed.

`make smoke` passed all six native modes (`success`, `stale`, `auth`, `network`, `rate`, `hang`) on the installed Omarchy/Qt environment above. The native run requires access to the Wayland compositor outside the filesystem/network sandbox. The fixture adapter never contacts GitHub.

| Acceptance condition | Evidence |
| --- | --- |
| Native bar sizing, no hover tooltip | Native WidgetButton has horizontal height / vertical width equal to the bar size, an empty tooltip, a contribution-bearing accessible name, and a Tab target. Fixture render shows the GitHub glyph/count aligned with a neighboring native volume glyph. |
| Compact short heatmaps | Qt tests verify weekday/date labels omit counts in both periods, with full date/count in hover and focus tooltips and accessible names. Arrow navigation and padding exclusion pass. |
| Annual fit and responsive width | Native annual Stats fits the actual calendar columns plus weekday gutter and popup insets. Work tabs return to normal width. The capped 220×160 popup scrolls; annual overflow initially shows newest dates. Qt tests check 10-unit squares, 3-unit gaps, full-width fit, period entry, and non-overlapping visible month labels. Labels without enough room in a partial edge month are omitted. |
| Preserve browsing and reveal focus | Qt snapshot replacement and real successful/failed native refreshes retain the browsed annual offset. Native focus reveals oldest and newest dates under the narrow cap; Qt tests send arrows across annual columns/rows. |
| Stats and explanations | Native assertions check the compact metric values, precise contribution/authorship names, UTC calendar accessible explanation, current stars, language percentages and byte explanations. Supplemental InfoText explanations support both hover and focus. |
| Work presentation and links | Both native tabs retain correct item/View all URLs, draft/private/overlapping-role names and external-link affordances. A separate two-row probe verifies `2 of 42 shown`, an item separator, and a stale work timestamp. |
| Independent freshness and errors | A repository-only stale probe leaves Activity fresh and displays its own stale timestamp. Failed manual refresh retains every section's data/timestamp and visible stale/failure guidance; successful refresh hides redundant healthy status. Authentication/network/rate/timeout modes still pass. |

Opt-in `STATS_CAPTURE_DIR=/tmp/github-stats-appearance-captures make smoke` renders fixture-only bar, week, month, annual, narrow annual, and work views using Qt's item capture. These renders were inspected for glyph rendering, bar alignment, compact metrics, date labels, annual month spacing, badge wrapping, and native separators. The annual render shows the full calendar; the narrow render shows the latest dates with a horizontal scrollbar. Captures are temporary and contain no production account data. Item captures do not establish physical screen-edge placement or physical input behavior.

The earlier maintainer confirmation applies to the previous presentation. **Physical checks still to repeat for this revision:** installed horizontal/vertical bar appearance, visible focus under physical Tab/arrow input, tooltip readability, Escape/outside-click dismissal, browser activation, and popup placement at screen edges or on a genuinely narrow display. Native geometry, focus mechanics, keyboard events, dismissal callbacks, and links are automated evidence, not a substitute for those observations. Screen-reader announcement quality, a second physical monitor, and a clean interactive installation remain unverified as above.

### Fixed popup follow-up — 2026-10-28 (#17)

The maintainer preferred the scrolling annual calendar and stable popup dimensions. The updated #17 specification supersedes annual-only widening: the popup now requests a fixed 370×520 theme-scaled size for every tab/period and uses the native screen caps. Longer content, including the refresh footer when necessary, scrolls vertically inside the card. Annual tiles remain compact and scroll horizontally.

The new native size-stability regression failed before the production change with `Switching tab or period resized the popup: 370×700 instead of 370×488`. After the change, `make check` passed (23 service/model fixtures, 9 Qt cases, lint and manifest validation; existing dynamic host/theme warnings remain), and `make smoke` passed all six modes. `git diff --check` passed.

Native assertions now verify equal width/height across all tabs and periods, reopening, refreshing, and successful/failed refresh completion. Annual entry starts at the newest dates at the regular narrow width; manual offsets survive tab switches and refreshes. Focus still reveals dates at either end. The constrained 220×160 probe restores the actual production size bindings before testing reopening/refresh, rather than installing replacement formulas in the test.

Fixture item captures in `/tmp/github-stats-fixed-captures` were inspected: week, month, annual, PRs and Issues all have the same 541×781 rendered content extent on this host. The annual capture shows the newest dates and scrollbar at the right; the month view uses internal vertical scrolling. These are content captures, not physical window-position observations. Physical input, focus visibility and screen-edge placement still require the checks listed above. No data-service, query, authentication or calendar-semantics changes were made.

### Full-content Stats follow-up — 2026-10-28 (#17)

The maintainer requires 7-day, 30-day and 12-month Stats to fit vertically inside the fixed popup. This supersedes the earlier allowance for scrolling to the Stats footer. The popup remains 370×520 theme-scaled units. Month dates now sit inside compact colored cells; Activity shares a line with its date range; current stars share the repository heading; all language shares use a two-column grid. Stale labels remain visible beside their sections, with original section timestamps available on hover/focus and through accessible descriptions. The healthy footer uses a short local timestamp; error/retry guidance remains visible.

The native regression reproduced the previous overflow: `Stats month requires vertical scrolling: 668 > 488`. The new native fit assertions require the complete content height to stay within the viewport and the Refresh control to remain visible. A worst-case fixture supplies a six-row month and all six language shares (top five plus Other). All three Stats periods are checked after successful and failed refreshes, preserving fixed bounds, annual newest-first entry, manual browsing and focused-tile reveal. Work lists and the artificial 220×160 screen-cap probe retain scrolling for accessibility.

`make check` passed: 23 service/model fixtures, 11 Qt cases including the six-row compact-month label/focus case and the high-intensity date-contrast case, QML lint and manifest validation. Existing dynamic host/theme lint warnings remain. `make smoke` passed all six modes. `git diff --check` passed.

Fixture content and complete card renders in `/tmp/github-stats-full-fit-captures` were inspected. The six-row month shows every date, four activity metrics, all six language shares, stars and Refresh without vertical scrolling. Complete card renders also establish readable dates on the actual themed backgrounds. The stale six-row month keeps both stale labels, the network guidance and refresh footer fully visible. Annual scrolling still opens on the newest dates. No production account data was captured. Physical input, screen-reader quality and physical screen-edge checks remain as recorded above; a screen too small for the normal fixed card still uses native bounds and accessible overflow rather than clipping content.

The Spec review caught matching foreground/accent colors making overlaid month dates unreadable at the highest intensity. Date text now selects black or white against the cell fill composited over the popup background. A regression first reproduced white-on-white, then passed for both light and dark matching palettes and live theme changes. The native worst-case month also includes a fourth-quartile cell; its complete card render was rechecked.

### Adaptive popup and original heatmaps — 2026-10-29 (#17)

The maintainer prefers the original heatmap sizes and a popup height that follows each view, superseding the fixed-height/forced-compact refinements above. Restored the pre-cleanup dimensions: 82-unit weekly day cells, 58-unit monthly cells, 22-unit annual squares, 4-unit gaps and the original chart height allowance (all theme-scaled). Short-view dates sit below the 28-unit contribution strips; repeated counts remain hidden, with full details available on hover/focus. The annual calendar remains narrow, horizontally scrollable and newest-first.

The popup now uses native `fittedContentHeight(content.implicitHeight)`, including padding/borders and the available-screen cap. It grows/shrinks for Stats, work lists and changing refresh/error content. It no longer reserves a fixed-height blank area. Scrollable overflow remains available when content reaches the native screen limit. Removing month date overlays also removes their now-unused contrast helper and test-only palette fields; separate date labels retain normal theme foreground contrast.

The updated regression first reproduced the fixed popup's wasted space: `Popup reserves blank space: 488 for 302 content`. `make check` then passed with 23 service/model fixtures, 10 Qt cases, QML lint and manifest validation; existing dynamic host/theme lint warnings remain. Restored-size tests cover the original tile dimensions, separate dates, six-row months, hover/focus details, annual overflow, keyboard reveal and refresh preservation. `make smoke` passed all six modes, with adaptive-height assertions for growth, shrinkage, no reserved blank space, visible uncapped footers and scrolling only at the screen cap. `git diff --check` passed.

Fixture card renders in `/tmp/github-stats-adaptive-captures` were inspected. Successful-refresh cards measured 592×662 pixels (week), 592×1152 (six-row month) and 592×870 (year) on this host: common narrow width, content-dependent heights and native padding below the footer. The renders show the restored spacing, readable separate dates, all metric/repository values and the newest annual dates. Stale/error cases and the artificial 220×160 cap also passed native checks. No production account data was captured. Physical input, screen-reader quality and physical screen-edge observations remain limited as recorded above.
