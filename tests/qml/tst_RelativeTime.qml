import QtQuick
import QtTest
import "../.." as Plugin

Item {
    Plugin.RelativeTime { id: label; timestamp: Date.parse("2026-10-29T09:00:00Z") }
    TestCase {
        name: "RelativeUpdateTime"
        when: windowShown
        function test_relative_and_exact_details() {
            label.now = Date.parse("2026-10-29T09:00:30Z")
            compare(label.text, "Updated just now")
            label.now = Date.parse("2026-10-29T09:02:00Z")
            compare(label.text, "Updated 2m ago")
            label.now = Date.parse("2026-10-29T11:00:00Z")
            compare(label.text, "Updated 2h ago")
            label.now = Date.parse("2026-10-31T09:00:00Z")
            compare(label.text, "Updated 2d ago")
            label.now = Date.parse("2026-11-06T09:00:00Z")
            verify(label.text.indexOf("ago") < 0)
            verify(label.tooltipText.length > 0)
            compare(label.Accessible.description, label.tooltipText)
            label.forceActiveFocus()
            tryCompare(findChild(label, "info-tooltip"), "visible", true)
        }
    }
}
