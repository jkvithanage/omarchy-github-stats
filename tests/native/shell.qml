import QtQuick
import Quickshell
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "../.." as Plugin

ShellRoot {
    id: root
    property int stage: 0
    property var keyboardTester: null
    property var settledState: null
    readonly property string mode: Quickshell.env("STATS_FIXTURE") || "success"

    Plugin.Service { id: service }
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
        Plugin.Widget { id: first; bar: bar; anchors.left: parent.left }
        Plugin.Widget { id: second; bar: bar; anchors.right: parent.right }
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

    function check() {
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
            if (root.mode !== "success") {
                var expected = { auth: "authentication", network: "network", rate: "rate-limit", hang: "timeout" }[root.mode]
                if (service.errorKind !== expected) throw new Error("Unexpected service failure state")
                if (service.lastSuccess !== 0 || service.todayCount !== null) throw new Error("Failure was presented as data")
                console.log("NATIVE_SMOKE_PASS " + root.mode)
                Qt.quit()
                return
            }
            if (service.todayCount !== 8 || service.identity.login !== "fixture") throw new Error("Shared fixture not published")
            if (first.service !== second.service) throw new Error("Widgets do not share a service")
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
                if (!textItem(scrollContent, "7 days") || !textItem(scrollContent, "Contributions: 8")
                    || !textItem(scrollContent, "Commit contributions: 3") || !textItem(scrollContent, "PRs authored: 2")
                    || !textItem(scrollContent, "Issues authored: 1")) throw new Error("Seven-day Stats missing")
                var date = service.stats.periods.week.days[0].date
                var tile = namedItem(scrollContent, "contribution-" + date)
                if (!tile || !tile.activeFocusOnTab || tile.Accessible.name.indexOf(date) < 0)
                    throw new Error("Accessible contribution tile missing")
                tile.forceActiveFocus()
                if (!tile.activeFocus) throw new Error("Tile did not receive native focus")
                var nextTile = namedItem(scrollContent, "contribution-" + service.stats.periods.week.days[1].date)
                nextTile.forceActiveFocus()
                var details = namedItem(scrollContent, "contribution-details")
                if (!details || details.text.indexOf(service.stats.periods.week.days[1].date) < 0)
                    throw new Error("Focus details missing")
                var stats = textItem(popup.contentItem[0], "Stats")
                stats.forceActiveFocus()
                if (!stats.focusable || !stats.activeFocusOnTab || !stats.activeFocus)
                    throw new Error("Native tab focus is unavailable")
                var monthControl = textItem(scrollContent, "30 days")
                if (!monthControl || !monthControl.focusable) throw new Error("Period controls missing")
                monthControl.clicked()
                root.stage = 4
                return
            }
            if (root.stage === 4) {
                if (first.periodIndex !== 1 || first.selectedStats.days.length !== 30)
                    throw new Error("Thirty-day period selection failed")
                var monthChart = namedItem(popup.contentItem[0], "contribution-chart")
                if (!monthChart || monthChart.layout.columns !== 7 || monthChart.layout.rows < 5)
                    throw new Error("Thirty-day calendar layout missing")
                first.tabIndex = 1
                first.tabIndex = 0
                if (first.periodIndex !== 1) throw new Error("Tab switch lost selected period")
                textItem(popup.contentItem[0], "12 months").clicked()
                root.stage = 5
                return
            }
            if (root.stage === 5) {
                var annualChart = namedItem(popup.contentItem[0], "contribution-chart")
                if (first.periodIndex !== 2 || first.selectedStats.days.length < 365
                    || annualChart.layout.rows !== 7 || annualChart.layout.months.length < 12)
                    throw new Error("Annual calendar layout missing")
                var lastDate = first.selectedStats.days[first.selectedStats.days.length - 1].date
                var lastTile = namedItem(annualChart, "contribution-" + lastDate)
                lastTile.forceActiveFocus()
                if (annualChart.contentX <= 0) throw new Error("Annual focus did not reveal the date horizontally")
                var previousWeek = first.selectedStats.days[first.selectedStats.days.length - 8].date
                namedItem(annualChart, "contribution-" + previousWeek).forceActiveFocus()
                popup.contentWidth = popup.fittedContentWidth(370, 220)
                popup.contentHeight = popup.fittedContentHeight(400, 160)
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
                var upperTile = namedItem(scroll, "contribution-" + first.selectedStats.days[0].date)
                upperTile.forceActiveFocus()
                var tooltip = null
                for (var child = 0; child < upperTile.data.length; child++) {
                    if (upperTile.data[child].objectName === "contribution-tooltip") tooltip = upperTile.data[child]
                }
                if (!tooltip || !tooltip.visible || tooltip.width > popup.width
                    || tooltip.text.indexOf(first.selectedStats.days[0].date) < 0)
                    throw new Error("Constrained tile tooltip details missing")
                root.keyboardTester.keyClick(Qt.Key_Escape, Qt.NoModifier, 0)
                root.stage = 7
                return
            }
            if (first.popupOpen) throw new Error("Escape dismissal failed")
            first.toggle()
            if (first.periodIndex !== 0 || first.tabIndex !== 0) throw new Error("Keyboard reopen did not reset Stats")
            // Native owner callback is also used by outside-click dismissal.
            popup.close()
            if (first.popupOpen) throw new Error("Native dismissal callback failed")
            first.toggle()
            if (first.periodIndex !== 0 || first.tabIndex !== 0) throw new Error("Reopen did not reset Stats and seven days")
            console.log("NATIVE_SMOKE_PASS success")
            Qt.quit()
        } catch (error) {
            console.error("Native smoke failed: " + error.message)
            smokeTimer.stop()
            Qt.quit()
        }
    }
}
