import QtQuick
import QtTest
import "../.." as Plugin
import "../../ServiceModel.js" as Model

Item {
    width: 360
    height: 600
    Item { id: beforeChart; activeFocusOnTab: true }
    Plugin.Heatmap {
        id: chart
        width: 220
        period: "week"
        periodStats: null
    }
    Item { id: afterChart; activeFocusOnTab: true }
    TestCase {
        name: "HeatmapKeyboard"
        when: windowShown

        function init() {
            beforeChart.forceActiveFocus()
            chart.width = 220
            chart.periodStats = null
            chart.entryDate = ""
            chart.initialPositionPending = true
        }

        function namedChildren(item, name) {
            var result = item.objectName === name ? [item] : []
            for (var i = 0; i < item.children.length; i++) result = result.concat(namedChildren(item.children[i], name))
            return result
        }

        function showPeriod(period, from, count) {
            var days = []
            for (var i = 0; i < count; i++) days.push({
                date: new Date(Date.parse(from + "T00:00:00Z") + i * 86400000).toISOString().slice(0, 10),
                contributionCount: i === count - 1 ? 8 : 0, contributionLevel: i === count - 1 ? "SECOND_QUARTILE" : "NONE"
            })
            chart.period = period
            chart.periodStats = { layout: Model.calendarLayout(days, period) }
            wait(0)
        }

        function test_short_labels_and_details() {
            var periods = ["week", "month"]
            for (var i = 0; i < periods.length; i++) {
                showPeriod(periods[i], "2026-10-01", i === 0 ? 7 : 30)
                var tile = findChild(chart, "contribution-2026-10-01")
                var label = findChild(tile, "short-date-label")
                compare(label.text, i === 0 ? "Thu\n01" : "01")
                compare(tile.Accessible.name, "2026-10-01: 0 contributions")
                var tooltip = findChild(tile, "contribution-tooltip")
                mouseMove(tile, 5, 5)
                tryCompare(tooltip, "visible", true)
                mouseMove(chart, chart.width - 2, chart.height - 2)
                tile.forceActiveFocus()
                tryCompare(tooltip, "visible", true)
                compare(tooltip.text, tile.Accessible.name)
            }
        }

        function test_original_short_view_sizes_keep_dates_below_tiles() {
            chart.width = 338
            showPeriod("week", "2026-10-19", 7)
            compare(chart.tileHeight, 82)
            var weeklyLabel = findChild(findChild(chart, "contribution-2026-10-19"), "short-date-label")
            verify(weeklyLabel.y >= 28)
            showPeriod("month", "2026-08-29", 30)
            compare(chart.layout.rows, 6)
            compare(chart.tileHeight, 58)
            var first = findChild(chart, "contribution-2026-08-29")
            var label = findChild(first, "short-date-label")
            verify(label.visible && label.y >= 28 && label.y + label.height <= first.height)
            compare(label.text, "29")
            first.forceActiveFocus()
            tryCompare(findChild(first, "contribution-tooltip"), "visible", true)
            compare(first.Accessible.name, "2026-08-29: 0 contributions")
        }

        function test_annual_fit_overflow_refresh_and_period_entry() {
            showPeriod("year", "2025-10-26", 365)
            compare(chart.tileWidth, 22)
            compare(chart.gap, 4)
            compare(chart.contentX, chart.contentWidth - chart.width)
            chart.contentX = 96
            // A refresh replaces delegates but keeps manual browsing at the same dates.
            showPeriod("year", "2025-10-26", 365)
            compare(chart.contentX, 96)
            chart.width = chart.contentWidth
            wait(0)
            compare(chart.contentX, 0)
            var labels = namedChildren(chart, "calendar-month-label").filter(function(label) { return label.visible })
            verify(labels.length >= 11)
            for (var i = 1; i < labels.length; i++)
                verify(labels[i - 1].x + labels[i - 1].width <= labels[i].x, "Month labels overlap")
            chart.width = 220
            showPeriod("week", "2026-10-19", 7)
            compare(chart.contentX, 0)
            showPeriod("year", "2025-10-26", 365)
            compare(chart.contentX, chart.contentWidth - chart.width)
        }

        function test_week_and_month_navigation() {
            showPeriod("week", "2026-10-19", 7)
            var first = findChild(chart, "contribution-2026-10-19")
            first.forceActiveFocus()
            keyClick(Qt.Key_Right)
            tryCompare(findChild(chart, "contribution-2026-10-20"), "activeFocus", true)
            showPeriod("month", "2026-09-26", 30)
            var firstMonth = findChild(chart, "contribution-2026-09-26")
            firstMonth.forceActiveFocus()
            keyClick(Qt.Key_Down)
            tryCompare(findChild(chart, "contribution-2026-10-03"), "activeFocus", true)
            var padding = findChild(chart, "calendar-padding")
            verify(padding && !padding.activeFocusOnTab)
        }

        function test_single_tab_stop_and_reentry() {
            var periods = ["week", "month", "year"]
            var counts = [7, 30, 365]
            var latest = ["2025-11-01", "2025-11-24", "2026-10-25"]
            var previous = ["2025-10-31", "2025-11-23", "2026-10-18"]
            for (var i = 0; i < periods.length; i++) {
                showPeriod(periods[i], "2025-10-26", counts[i])
                beforeChart.forceActiveFocus()
                keyClick(Qt.Key_Tab)
                tryCompare(findChild(chart, "contribution-" + latest[i]), "activeFocus", true)
                keyClick(Qt.Key_Left)
                var remembered = findChild(chart, "contribution-" + previous[i])
                verify(remembered.activeFocus)
                keyClick(Qt.Key_Tab)
                tryCompare(afterChart, "activeFocus", true)
                keyClick(Qt.Key_Backtab)
                tryCompare(remembered, "activeFocus", true)
                keyClick(Qt.Key_Backtab)
                tryCompare(beforeChart, "activeFocus", true)
            }
            chart.periodStats = null
            beforeChart.forceActiveFocus()
            keyClick(Qt.Key_Tab)
            tryCompare(afterChart, "activeFocus", true)
        }

        function test_refresh_and_rollover_keep_valid_focus() {
            showPeriod("week", "2026-10-19", 7)
            findChild(chart, "contribution-2026-10-22").forceActiveFocus()
            showPeriod("week", "2026-10-19", 7)
            tryCompare(findChild(chart, "contribution-2026-10-22"), "activeFocus", true)
            showPeriod("week", "2026-10-23", 7)
            tryCompare(findChild(chart, "contribution-2026-10-29"), "activeFocus", true)
            var tabStops = 0
            for (var i = 0; i < 7; i++) {
                var day = "2026-10-" + (23 + i)
                if (findChild(chart, "contribution-" + day).activeFocusOnTab) tabStops++
            }
            compare(tabStops, 1)
            keyClick(Qt.Key_Right)
            verify(findChild(chart, "contribution-2026-10-29").activeFocus)
            keyClick(Qt.Key_Tab)
            tryCompare(afterChart, "activeFocus", true)
        }

        function test_annual_navigation_and_scrolling() {
            showPeriod("year", "2025-10-26", 365)
            var last = findChild(chart, "contribution-2026-10-25")
            last.forceActiveFocus()
            verify(chart.contentX > 0)
            keyClick(Qt.Key_Left)
            tryCompare(findChild(chart, "contribution-2026-10-18"), "activeFocus", true)
            keyClick(Qt.Key_Up)
            tryCompare(findChild(chart, "contribution-2026-10-17"), "activeFocus", true)
            keyClick(Qt.Key_Home) // Unhandled keys must leave focus intact.
            verify(findChild(chart, "contribution-2026-10-17").activeFocus)
            var tooltip = findChild(findChild(chart, "contribution-2026-10-17"), "contribution-tooltip")
            verify(tooltip !== null, 'Focused tiles need details outside the clipped chart')
            tryCompare(tooltip, "visible", true)
            compare(tooltip.text, "2026-10-17: 0 contributions")
            verify(tooltip.width <= chart.width)
        }
    }
}
