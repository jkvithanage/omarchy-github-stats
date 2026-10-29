import QtQuick
import QtTest
import "../.." as Plugin

Item {
    width: 220
    height: 200
    Plugin.InfoText {
        id: title
        width: 200
        text: "A long pull request title that wraps across several lines "
        tooltipText: "Open fixture/repo #1 in browser"
        link: true
    }
    SignalSpy { id: activation; target: title; signalName: "activated" }
    TestCase {
        name: "LinkedTitle"
        when: windowShown
        function test_keyboard_pointer_and_accessible_activation() {
            verify(title.height > title.font.pixelSize * 2)
            compare(title.Accessible.role, Accessible.Link)
            title.forceActiveFocus()
            verify(title.activeFocus && title.font.underline)
            keyClick(Qt.Key_Return)
            compare(activation.count, 1)
            keyClick(Qt.Key_Space)
            compare(activation.count, 2)
            title.Accessible.pressAction()
            compare(activation.count, 3)
            mouseClick(title, 10, 10)
            compare(activation.count, 4)
            compare(title.Accessible.description, title.tooltipText)
        }
    }
}
