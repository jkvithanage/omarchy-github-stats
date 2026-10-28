import QtQuick
import QtTest
import qs.Commons as Commons
import "../.." as Plugin
import "../../ServiceModel.js" as Model

Item {
    width: 360
    height: 600
    Plugin.Heatmap {
        id: chart
        width: 220
        period: "week"
        periodStats: null
    }
    TestCase {
        name: "HeatmapKeyboard"
        when: windowShown

        function init() {
            Commons.Color.foreground = "#eeeeee"
            Commons.Color.accent = "#6699cc"
            chart.width = 220
            chart.periodStats = null
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

        function test_month_dates_contrast_with_highest_intensity_and_theme_changes() {
            chart.period = "month"
            chart.periodStats = { layout: Model.calendarLayout([
                { date: "2026-09-01", contributionCount: 8, contributionLevel: "FOURTH_QUARTILE" }
            ], "month") }
            Commons.Color.foreground = "#ffffff"
            Commons.Color.accent = "#ffffff"
            wait(0)
            var label = findChild(findChild(chart, "contribution-2026-09-01"), "short-date-label")
            compare(label.color, Qt.rgba(0, 0, 0, 1))
            Commons.Color.foreground = "#101010"
            Commons.Color.accent = "#101010"
            tryCompare(label, "color", Qt.rgba(1, 1, 1, 1))
        }

        function test_six_row_month_keeps_dates_inside_compact_tiles() {
            chart.width = 338
            showPeriod("month", "2026-08-29", 30)
            compare(chart.layout.rows, 6)
            verify(chart.implicitHeight <= 160, "Six rows must leave room for the Stats summaries and footer")
            var first = findChild(chart, "contribution-2026-08-29")
            var label = findChild(first, "short-date-label")
            verify(label.visible && label.y >= 0 && label.y + label.height <= first.height)
            compare(label.text, "29")
            first.forceActiveFocus()
            tryCompare(findChild(first, "contribution-tooltip"), "visible", true)
            compare(first.Accessible.name, "2026-08-29: 0 contributions")
        }

        function test_annual_fit_overflow_refresh_and_period_entry() {
            showPeriod("year", "2025-10-26", 365)
            compare(chart.tileWidth, 10)
            compare(chart.gap, 3)
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
