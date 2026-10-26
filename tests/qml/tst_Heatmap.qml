import QtQuick
import QtTest
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
            compare(tooltip.text, "2026-10-17: 0 contributions (UTC)")
            verify(tooltip.width <= chart.width)
        }
    }
}
