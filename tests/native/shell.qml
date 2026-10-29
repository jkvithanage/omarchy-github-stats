import QtQuick
import Quickshell
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "../.." as Plugin
import "../../ServiceModel.js" as Model

ShellRoot {
    id: root
    property int stage: 0
    property var keyboardTester: null
    property var settledState: null
    property string openedUrl: ""
    property var beforeManualRefresh: null
    property real regularWidth: 0
    property real weekHeight: 0
    property real monthHeight: 0
    property real annualBrowseX: 0
    property var captured: ({})
    property bool capturePending: false
    property var constrainedPopup: null
    property bool constrainPopup: false
    readonly property string mode: Quickshell.env("STATS_FIXTURE") || "success"

    // Temporary bounds overrides restore the real production bindings after the narrow-screen probe.
    Binding {
        target: root.constrainedPopup
        property: "contentWidth"
        value: Math.min(root.regularWidth, 220)
        when: root.constrainPopup
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        target: root.constrainedPopup
        property: "contentHeight"
        value: Math.min(root.weekHeight, 160)
        when: root.constrainPopup
        restoreMode: Binding.RestoreBindingOrValue
    }

    Plugin.Service { id: service }
    Plugin.WorkList {
        id: linkProbe
        width: 300
        section: service.prs
        refreshing: service.refreshing
        sectionName: "PRs"
        onOpenUrl: function(url) { root.openedUrl = url }
    }
    Plugin.WorkList {
        id: issueLinkProbe
        width: 300
        section: service.issues
        refreshing: service.refreshing
        sectionName: "Issues"
        onOpenUrl: function(url) { root.openedUrl = url }
    }
    QtObject {
        id: facade
        function serviceFor(id) { return id === "omarchy-github-stats" ? service : null }
    }
    PluginBarApi {
        id: bar
        pluginId: "omarchy-github-stats"
        moduleName: pluginId
        shell: facade
        foreground: "#eeeeee"
        barForeground: foreground
        fontFamily: "monospace"
        barSize: 32
        _requestPopout: function(owner) { bar.activePopout = owner }
        _releasePopout: function(owner) { if (bar.activePopout === owner) bar.activePopout = null }
    }
    PanelWindow {
        id: testWindow
        implicitWidth: 420
        implicitHeight: 32
        color: "#202020"
        Item {
            id: barContent
            anchors.fill: parent
            Plugin.Widget { id: first; bar: bar; anchors.left: parent.left }
            WidgetButton { bar: bar; text: ""; anchors.centerIn: parent }
            Plugin.Widget { id: second; bar: bar; anchors.right: parent.right }
        }
    }
    Timer {
        id: smokeTimer
        interval: 100
        repeat: true
        running: true
        onTriggered: root.check()
    }

    function popupFor(widget) {
        for (var i = 0; i < widget.data.length; i++) {
            if ("anchorItem" in widget.data[i]) return widget.data[i]
        }
        throw new Error("Native popup missing")
    }

    function textItem(item, text) {
        if (item.text === text) return item
        for (var i = 0; i < item.children.length; i++) {
            var match = textItem(item.children[i], text)
            if (match) return match
        }
        return null
    }

    function namedItem(item, name) {
        if (item.objectName === name) return item
        for (var i = 0; i < item.children.length; i++) {
            var match = namedItem(item.children[i], name)
            if (match) return match
        }
        return null
    }

    function showLargestStatsFixture() {
        var stats = JSON.parse(JSON.stringify(service.model.stats))
        var days = []
        for (var i = 0; i < 30; i++) days.push({
            date: new Date(Date.parse("2026-08-29T00:00:00Z") + i * 86400000).toISOString().slice(0, 10),
            contributionCount: i === 29 ? 8 : 0,
            contributionLevel: i === 29 ? "FOURTH_QUARTILE" : "NONE"
        })
        stats.periods.month.days = days
        stats.periods.month.from = "2026-08-29T00:00:00Z"
        stats.periods.month.to = "2026-09-27T23:59:59Z"
        stats.periods.month.layout = Model.calendarLayout(days, "month")
        if (stats.periods.month.layout.rows !== 6) throw new Error("Largest month fixture must occupy six rows")
        service.model.stats = stats
        var repositories = JSON.parse(JSON.stringify(service.model.repositories))
        repositories.data.languages = [
            { name: "JavaScript", bytes: 30, percentage: 30 },
            { name: "Python", bytes: 20, percentage: 20 },
            { name: "TypeScript", bytes: 15, percentage: 15 },
            { name: "Jupyter Notebook", bytes: 15, percentage: 15 },
            { name: "C++", bytes: 10, percentage: 10 },
            { name: "Other", bytes: 10, percentage: 10 }
        ]
        service.model.repositories = repositories
        service.modelChanged()
    }

    function assertAdaptivePopup(popup) {
        var scroll = popup.contentItem[0]
        if (first.tabIndex === 0) {
            var primary = namedItem(scroll, "contribution-total")
            if (!primary || primary.Accessible.name.indexOf(["7 days", "30 days", "12 months"][first.periodIndex]) < 0)
                throw new Error("Primary contribution total lost its selected-period association")
        }
        if (root.regularWidth > 0 && popup.contentWidth !== root.regularWidth)
            throw new Error("The annual view widened the popup")
        if (scroll.availableHeight - scroll.contentHeight > 1)
            throw new Error("Popup reserves blank space: " + scroll.availableHeight + " for " + scroll.contentHeight + " content")
        if (popup.contentHeight > popup.availableCardHeight + 1)
            throw new Error("Adaptive popup exceeds the available screen height")
        if (scroll.contentHeight > scroll.availableHeight + 1) {
            if (popup.contentHeight < popup.availableCardHeight - 1)
                throw new Error("Popup scrolls before using the available screen height")
        } else {
            var refresh = namedItem(scroll, "refresh-button")
            if (refresh.mapToItem(scroll, 0, refresh.height).y > scroll.height + 1)
                throw new Error("Uncapped popup hid the refresh footer")
        }
    }

    function capture(item, name) {
        var directory = Quickshell.env("STATS_CAPTURE_DIR")
        if (!directory || root.captured[name]) return false
        root.captured[name] = true
        root.capturePending = true
        if (!item.grabToImage(function(result) {
            result.saveToFile(directory + "/" + name + ".png")
            root.capturePending = false
        })) root.capturePending = false
        return root.capturePending
    }

    function check() {
        if (root.capturePending) return
        try {
            if (root.settledState) {
                if (service.refreshing) throw new Error("Idle clock tick started an unexpected refresh")
                if (service.lastSuccess !== root.settledState.lastSuccess
                    || service.retryAt !== root.settledState.retryAt
                    || service.errorKind !== root.settledState.errorKind
                    || service.model.serial !== root.settledState.serial)
                    throw new Error("Idle clock tick discarded published service state")
                if (service.now < root.settledState.at + 2000) return
            } else if (!service.refreshing) {
                // Observe the real service across multiple one-second ticks,
                // including cached data and rate-limit/error state.
                root.settledState = {
                    at: service.now, lastSuccess: service.lastSuccess,
                    retryAt: service.retryAt, errorKind: service.errorKind, serial: service.model.serial
                }
                return
            }
            if (service.refreshing) {
                // Many monitor/manual triggers must remain one transaction.
                if (root.stage === 0) { service.refresh(); service.refresh(); root.stage = 1 }
                return
            }
            if (root.mode !== "success" && root.mode !== "stale") {
                var expected = { auth: "authentication", network: "network", rate: "rate-limit", hang: "timeout" }[root.mode]
                if (service.errorKind !== expected) throw new Error("Unexpected service failure state")
                if (service.lastSuccess !== 0 || service.todayCount !== null) throw new Error("Failure was presented as data")
                console.log("NATIVE_SMOKE_PASS " + root.mode)
                Qt.quit()
                return
            }
            if (service.todayCount !== 8 || service.identity.login !== "fixture") throw new Error("Shared fixture not published")
            if (first.service !== second.service) throw new Error("Widgets do not share a service")
            if (root.stage === 9) {
                root.assertAdaptivePopup(popupFor(first))
                if (root.capture(popupFor(first).contentItem[0].parent.parent, root.mode + "-" + first.period + "-card")) return
                if (first.periodIndex < 2) { first.periodIndex++; return }
                console.log("NATIVE_SMOKE_PASS " + root.mode)
                Qt.quit()
                return
            }
            if (root.stage === 8) {
                if (root.mode === "stale") {
                    if (service.errorKind !== "network" || !service.stale || !service.repositories.stale || !service.prs.stale || !service.issues.stale
                        || service.lastSuccess !== root.beforeManualRefresh.stats
                        || service.repositories.lastSuccess !== root.beforeManualRefresh.repositories
                        || service.prs.lastSuccess !== root.beforeManualRefresh.prs
                        || service.issues.lastSuccess !== root.beforeManualRefresh.issues)
                        throw new Error("Failed manual refresh lost stale data or changed section freshness")
                } else if (service.lastSuccess <= root.beforeManualRefresh.stats || service.errorKind !== "") {
                    throw new Error("Manual Refresh did not publish fresh data")
                }
                root.assertAdaptivePopup(popupFor(first))
                var refreshedContent = popupFor(first).contentItem[0]
                if (Math.abs(namedItem(refreshedContent, "contribution-chart").contentX - root.annualBrowseX) > 1)
                    throw new Error("Refresh reset annual browsing")
                if (root.mode === "stale" && (!namedItem(refreshedContent, "stats-stale").visible
                    || !namedItem(refreshedContent, "repositories-stale").visible
                    || !namedItem(refreshedContent, "refresh-status").visible))
                    throw new Error("Section-specific stale states or failure guidance missing: "
                        + first.popupOpen + "/tab=" + first.tabIndex + "/stats=" + namedItem(refreshedContent, "stats-stale").visible
                        + "/repos=" + namedItem(refreshedContent, "repositories-stale").visible + "/status=" + namedItem(refreshedContent, "refresh-status").visible)
                if (root.mode === "success" && namedItem(refreshedContent, "refresh-status").visible)
                    throw new Error("Healthy footer retained redundant status")
                root.showLargestStatsFixture()
                first.periodIndex = 0
                root.stage = 9
                return
            }
            if (root.stage < 2) {
                first.toggle()
                first.tabIndex = 2
                first.close()
                first.toggle()
                if (!first.popupOpen || first.tabIndex !== 0) throw new Error("Popup did not reset to Stats")
                root.stage = 2
                return
            }
            var popup = popupFor(first)
            if (root.stage === 2) {
                // The popup must expose native tab-focus targets and an
                // Escape shortcut independent of child event consumption.
                popup._backingWindow.requestActivate()
                root.keyboardTester = Qt.createQmlObject('import QtTest; TestEvent {}', popup.contentItem[0])
                root.stage = 3
                return
            }
            if (root.stage === 3) {
                var scrollContent = popup.contentItem[0]
                var contributionTotal = namedItem(scrollContent, "contribution-total")
                if (!contributionTotal || contributionTotal.text !== "8 contributions"
                    || contributionTotal.Accessible.name.indexOf("7 days") < 0
                    || contributionTotal.font.pixelSize <= namedItem(scrollContent, "metric-Commits").font.pixelSize
                    || namedItem(scrollContent, "metric-Contributions"))
                    throw new Error("Selected-period contributions lack a distinct primary metric")
                var originalStats = service.model.stats
                var zeroStats = JSON.parse(JSON.stringify(originalStats))
                zeroStats.periods.week.contributions = 0
                service.model.stats = zeroStats
                service.modelChanged()
                if (contributionTotal.text !== "0 contributions") throw new Error("Successful zero contribution total is unavailable")
                service.model.stats = null
                service.modelChanged()
                if (contributionTotal.text !== "Contributions unavailable") throw new Error("Missing contribution data is shown as zero")
                var originalActive = service.model.active
                service.model.active = {}
                service.modelChanged()
                if (contributionTotal.text !== "Loading contributions…") throw new Error("Initial contributions are not labeled loading")
                service.model.active = originalActive
                service.model.stats = originalStats
                service.modelChanged()
                root.assertAdaptivePopup(popup)
                if (root.capture(barContent, "bar") || root.capture(scrollContent, "week")) return
                root.regularWidth = popup.contentWidth
                root.weekHeight = popup.contentHeight
                var trigger = namedItem(first, "github-trigger")
                if (!trigger || trigger.implicitHeight !== bar.barSize || trigger.tooltipText !== ""
                    || !trigger.activeFocusOnTab || trigger.Accessible.name.indexOf("8 contributions") < 0)
                    throw new Error("Native horizontal bar sizing or accessible trigger missing")
                bar.vertical = true
                if (trigger.implicitWidth !== bar.barSize) throw new Error("Native vertical bar width mismatch")
                bar.vertical = false
                if (!textItem(scrollContent, "7 days") || !textItem(scrollContent, "8 contributions")
                    || !textItem(scrollContent, "Commits: 3") || !textItem(scrollContent, "PRs: 2")
                    || !textItem(scrollContent, "Issues: 1")
                    || namedItem(scrollContent, "metric-Commits").Accessible.name.indexOf("Commit contributions") < 0
                    || namedItem(scrollContent, "calendar-info").Accessible.description.indexOf("UTC") < 0)
                    throw new Error("Compact accessible seven-day Stats missing")
                if (namedItem(scrollContent, "repository-stars").Accessible.name !== "Stars: 12" || !textItem(scrollContent, "JavaScript: 60.0%")
                    || namedItem(scrollContent, "language-JavaScript").Accessible.description.indexOf("60 GitHub-reported language bytes") < 0
                    || service.repositories.data.repositoryCount !== 2)
                    throw new Error("Complete repository snapshots missing")
                var date = service.stats.periods.week.days[0].date
                var tile = namedItem(scrollContent, "contribution-" + date)
                if (!tile || tile.Accessible.name.indexOf(date) < 0)
                    throw new Error("Accessible contribution tile missing")
                tile.forceActiveFocus()
                if (!tile.activeFocus) throw new Error("Tile did not receive native focus")
                var nextTile = namedItem(scrollContent, "contribution-" + service.stats.periods.week.days[1].date)
                nextTile.forceActiveFocus()
                var details = null
                for (var t = 0; t < nextTile.data.length; t++) {
                    if (nextTile.data[t].objectName === "contribution-tooltip") details = nextTile.data[t]
                }
                if (!details || !details.visible || details.text.indexOf(service.stats.periods.week.days[1].date) < 0)
                    throw new Error("Focus details missing")
                var stats = textItem(popup.contentItem[0], "Stats")
                stats.forceActiveFocus()
                if (!stats.focusable || !stats.activeFocusOnTab || !stats.activeFocus)
                    throw new Error("Native tab focus is unavailable")
                var monthControl = textItem(scrollContent, "30 days")
                if (!monthControl || !monthControl.focusable) throw new Error("Period controls missing")
                var preview = JSON.parse(JSON.stringify(service.prs))
                preview.data.groups[0].total = 42
                var extraRow = JSON.parse(JSON.stringify(preview.data.groups[0].rows[0]))
                extraRow.id = "preview-extra"
                extraRow.number = 3
                extraRow.title = "Extra preview row"
                preview.data.groups[0].rows.push(extraRow)
                preview.stale = true
                preview.errorKind = "network"
                linkProbe.section = preview
                root.showLargestStatsFixture()
                monthControl.clicked()
                root.stage = 4
                return
            }
            if (root.stage === 4) {
                root.assertAdaptivePopup(popup)
                if (first.tabIndex === 0) {
                    root.monthHeight = popup.contentHeight
                    if (root.monthHeight <= root.weekHeight) throw new Error("Popup did not grow for the larger month view")
                }
                if (!textItem(linkProbe, "Authored · 2 of 42 shown") || !namedItem(linkProbe, "work-stale").visible
                    || !namedItem(linkProbe, "work-row-separator").visible)
                    throw new Error("Truncated preview total or independent work stale state missing")
                var workStatus = namedItem(linkProbe, "work-stale")
                if (workStatus.text !== "Showing saved PRs · refresh failed."
                    || workStatus.tooltipText.indexOf(new Date(linkProbe.section.lastSuccess).toLocaleString()) < 0)
                    throw new Error("Saved-work failure message or original timestamp missing")
                linkProbe.refreshing = true
                if (workStatus.text !== "Refreshing PRs · showing saved data…")
                    throw new Error("Refreshing cached work is indistinguishable from initial loading")
                var savedWorkSection = linkProbe.section
                linkProbe.section = null
                if (workStatus.text !== "Loading PRs…" || workStatus.tooltipText !== "No successful update yet.")
                    throw new Error("Initial loading is presented as saved or successful data")
                linkProbe.section = savedWorkSection
                linkProbe.refreshing = Qt.binding(function() { return service.refreshing })
                if (root.capture(popup.contentItem[0], "month")) return
                if (root.capture(popup.contentItem[0].parent.parent, "month-card")) return
                if (first.periodIndex !== 1 || first.selectedStats.days.length !== 30)
                    throw new Error("Thirty-day period selection failed")
                var monthChart = namedItem(popup.contentItem[0], "contribution-chart")
                if (!monthChart || monthChart.layout.columns !== 7 || monthChart.layout.rows < 5)
                    throw new Error("Thirty-day calendar layout missing")
                first.tabIndex = 1
                var prsBeforeFreshness = service.model.prs
                var olderPrs = JSON.parse(JSON.stringify(prsBeforeFreshness))
                olderPrs.lastSuccess = service.lastSuccess - 120000
                service.model.prs = olderPrs
                service.modelChanged()
                var tabFreshness = namedItem(popup.contentItem[0], "refresh-freshness")
                if (tabFreshness.timestamp !== olderPrs.lastSuccess || tabFreshness.text.indexOf("PRs") < 0)
                    throw new Error("PR footer incorrectly uses Activity freshness")
                first.tabIndex = 2
                if (tabFreshness.timestamp !== service.issues.lastSuccess || tabFreshness.text.indexOf("Issues") < 0)
                    throw new Error("Issue footer incorrectly uses Activity freshness")
                service.model.prs = prsBeforeFreshness
                service.modelChanged()
                first.tabIndex = 1
                var prList = namedItem(popup.contentItem[0], "pr-work-list")
                if (!prList || !prList.visible || !namedItem(prList, "work-link-1")
                    || !textItem(prList, "Authored · 1")
                    || !textItem(prList, "Review requests · 1"))
                    throw new Error("PR work previews missing")
                if (root.capture(popup.contentItem[0], "prs")) return
                var authoredLink = namedItem(prList, "work-link-1")
                if (authoredLink.Accessible.name.indexOf("Draft") < 0 || authoredLink.Accessible.name.indexOf("Private") < 0
                    || authoredLink.Accessible.name.indexOf("Review requested") < 0 || authoredLink.text.indexOf("Fixture PR 1") < 0 || authoredLink.tooltipText === "")
                    throw new Error("Draft/private/overlapping role or external-link affordance missing")
                var itemLink = namedItem(linkProbe, "work-link-1")
                if (!itemLink || !itemLink.activeFocusOnTab || textItem(linkProbe, "Open #1")) throw new Error("Keyboard title link missing or redundant Open button remains")
                itemLink.Accessible.pressAction()
                if (root.openedUrl !== "https://github.com/fixture/repo/pull/1") throw new Error("Item browser URL mismatch")
                var updated = namedItem(linkProbe, "work-updated-1")
                if (!updated || updated.Accessible.description !== updated.tooltipText || updated.text.indexOf("Updated ") !== 0)
                    throw new Error("Relative update time or exact accessible timestamp missing")
                textItem(linkProbe, "View all").clicked()
                if (decodeURIComponent(root.openedUrl).indexOf("is:open author:fixture") < 0)
                    throw new Error("View all browser filters mismatch")
                first.tabIndex = 2
                var issueList = namedItem(popup.contentItem[0], "issue-work-list")
                if (!issueList || !issueList.visible || !namedItem(issueList, "work-link-1")
                    || !textItem(issueList, "Assigned · 1"))
                    throw new Error("Issue work previews missing")
                if (root.capture(popup.contentItem[0], "issues")) return
                namedItem(issueLinkProbe, "work-link-1").Accessible.pressAction()
                if (root.openedUrl !== "https://github.com/fixture/repo/issues/1") throw new Error("Issue URL mismatch")
                textItem(issueLinkProbe, "View all").clicked()
                if (decodeURIComponent(root.openedUrl).indexOf("is:issue is:open author:fixture") < 0)
                    throw new Error("Issue View all filters mismatch")
                first.tabIndex = 0
                if (first.periodIndex !== 1) throw new Error("Tab switch lost selected period")
                textItem(popup.contentItem[0], "12 months").clicked()
                root.stage = 5
                return
            }
            if (root.stage === 5) {
                root.assertAdaptivePopup(popup)
                if (popup.contentHeight < popup.availableCardHeight - 1 && popup.contentHeight >= root.monthHeight)
                    throw new Error("Popup did not shrink after leaving the month view")
                var annualChart = namedItem(popup.contentItem[0], "contribution-chart")
                if (first.periodIndex !== 2 || first.selectedStats.days.length < 365
                    || annualChart.layout.rows !== 7 || annualChart.layout.months.length < 12)
                    throw new Error("Annual calendar layout missing")
                if (root.capture(popup.contentItem[0], "annual")) return
                var savedRepositoryState = service.model.repositories
                service.model.repositories = { data: savedRepositoryState.data, lastSuccess: savedRepositoryState.lastSuccess,
                    stale: true, errorKind: "network" }
                service.modelChanged()
                if (!namedItem(popup.contentItem[0], "repositories-stale").visible
                    || namedItem(popup.contentItem[0], "stats-stale").visible)
                    throw new Error("Independently stale repository state was hidden or staled Activity")
                service.model.repositories = savedRepositoryState
                service.modelChanged()
                if (annualChart.contentWidth <= annualChart.width
                    || Math.abs(annualChart.contentX - (annualChart.contentWidth - annualChart.width)) > 1)
                    throw new Error("Annual calendar did not initially show newest dates in the fixed popup")
                annualChart.contentX = 96
                first.tabIndex = 1
                first.tabIndex = 0
                if (Math.abs(annualChart.contentX - 96) > 1) throw new Error("Tab switching reset annual browsing")
                var lastDate = first.selectedStats.days[first.selectedStats.days.length - 1].date
                var lastTile = namedItem(annualChart, "contribution-" + lastDate)
                lastTile.forceActiveFocus()
                if (annualChart.contentX <= 0) throw new Error("Annual focus did not reveal the newest date")
                if (root.capture(annualChart, "focused-annual")) return
                var previousWeek = first.selectedStats.days[first.selectedStats.days.length - 8].date
                namedItem(annualChart, "contribution-" + previousWeek).forceActiveFocus()
                // Re-enter annual after constraining the card, so newest-first initialization runs.
                first.periodIndex = 0
                root.constrainedPopup = popup
                root.constrainPopup = true
                first.periodIndex = 2
                Commons.Color.foreground = "#ffddaa"
                root.stage = 6
                return
            }
            if (root.stage === 6) {
                var scroll = popup.contentItem[0]
                if (popup.width > 220 || popup.height > 160 || scroll.contentHeight <= scroll.availableHeight)
                    throw new Error("Constrained popup does not scroll")
                var title = textItem(scroll, "GitHub Stats · fixture")
                if (!title || String(title.color) !== "#ffddaa") throw new Error("Theme binding did not update")
                var narrowChart = namedItem(scroll, "contribution-chart")
                if (!root.captured["narrow"]) {
                    if (root.capture(narrowChart, "narrow")) return
                }
                if (Math.abs(narrowChart.contentX - (narrowChart.contentWidth - narrowChart.width)) > 1)
                    throw new Error("Narrow annual view did not start at newest dates: " + narrowChart.contentX + " / " + narrowChart.contentWidth + " / " + narrowChart.width + " / " + narrowChart.browsed)
                var upperTile = namedItem(scroll, "contribution-" + first.selectedStats.days[0].date)
                upperTile.forceActiveFocus()
                var tooltip = null
                for (var child = 0; child < upperTile.data.length; child++) {
                    if (upperTile.data[child].objectName === "contribution-tooltip") tooltip = upperTile.data[child]
                }
                if (narrowChart.contentX > 40) throw new Error("Focused oldest tile was not revealed")
                var newestTile = namedItem(scroll, "contribution-" + first.selectedStats.days[first.selectedStats.days.length - 1].date)
                newestTile.forceActiveFocus()
                if (narrowChart.contentX <= 0) throw new Error("Focused newest tile was not revealed")
                if (!tooltip || tooltip.width > popup.width
                    || tooltip.text.indexOf(first.selectedStats.days[0].date) < 0)
                    throw new Error("Constrained tile tooltip details missing")
                first.tabIndex = 1
                var constrainedLink = namedItem(namedItem(scroll, "pr-work-list"), "work-link-2")
                constrainedLink.forceActiveFocus()
                if (scroll.contentItem.contentY <= 0) throw new Error("Focused work link was not scrolled into view")
                root.keyboardTester.keyClick(Qt.Key_Escape, Qt.NoModifier, 0)
                root.stage = 7
                return
            }
            if (root.stage === 7) {
                if (first.popupOpen) throw new Error("Escape dismissal failed")
                root.constrainPopup = false
                first.toggle()
                if (first.periodIndex !== 0 || first.tabIndex !== 0) throw new Error("Keyboard reopen did not reset Stats")
                root.stage = 70
                return
            }
            if (root.stage === 70) {
                // Let native focus-grab changes settle between close/reopen events.
                popup.close()
                if (first.popupOpen) throw new Error("Native dismissal callback failed")
                root.stage = 71
                return
            }
            if (root.stage === 71) {
                first.toggle()
                root.stage = 72
                return
            }
            if (root.stage === 72) {
                if (first.periodIndex !== 0 || first.tabIndex !== 0) throw new Error("Reopen did not reset Stats and seven days")
                var weeklyChart = namedItem(popup.contentItem[0], "contribution-chart")
                namedItem(weeklyChart, "contribution-" + service.stats.periods.week.days[0].date).forceActiveFocus()
                first.close()
                root.stage = 73
                return
            }
            if (root.stage === 73) {
                first.toggle()
                root.stage = 74
                return
            }
            var reopenedChart = namedItem(popup.contentItem[0], "contribution-chart")
            if (reopenedChart.entryDate !== service.stats.periods.week.days[6].date)
                throw new Error("New popup session retained an older weekly keyboard entry")
            root.beforeManualRefresh = { stats: service.lastSuccess, repositories: service.repositories.lastSuccess,
                prs: service.prs.lastSuccess, issues: service.issues.lastSuccess }
            root.stage = 8
            root.settledState = null
            first.periodIndex = 2
            Qt.callLater(function() {
                var browsing = namedItem(popup.contentItem[0], "contribution-chart")
                browsing.contentX = 96
                root.annualBrowseX = browsing.contentX
                namedItem(popup.contentItem[0], "refresh-button").clicked()
                if (!service.refreshing) throw new Error("Manual Refresh did not start")
            })
        } catch (error) {
            console.error("Native smoke failed: " + error.message)
            smokeTimer.stop()
            Qt.quit()
        }
    }
}
