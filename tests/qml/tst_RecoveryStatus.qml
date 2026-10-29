import QtQuick
import QtTest
import "../.." as Plugin

Item {
    width: 240
    height: 400
    QtObject {
        id: service
        property string errorKind: "authentication"
        property string statusText: "Authentication needed: run gh auth login --hostname github.com in a terminal."
        property double retryAt: 0
        property double now: Date.parse("2026-10-29T09:00:00Z")
        property bool refreshing: false
    }
    Plugin.RecoveryStatus { id: status; width: 220; service: service }
    TextEdit { id: pasteTarget; visible: false }
    TestCase {
        name: "RecoveryGuidance"
        when: windowShown
        function test_authentication_copy_and_confirmation() {
            var action = findChild(status, "copy-login-command")
            verify(action.visible && action.activeFocusOnTab)
            compare(action.Accessible.role, Accessible.Button)
            action.forceActiveFocus()
            keyClick(Qt.Key_Return)
            pasteTarget.paste()
            compare(pasteTarget.text, "gh auth login --hostname github.com")
            compare(action.text, "Login command copied")
            compare(action.Accessible.name, "Login command copied")
            compare(action.Accessible.description, "gh auth login --hostname github.com")
            service.errorKind = "network"
            verify(!action.visible)
            service.errorKind = "authentication"
            compare(action.text, "Copy login command")
            action.Accessible.pressAction()
            status.visible = false
            status.visible = true
            compare(action.text, "Copy login command")
        }
        function test_rate_limit_countdown_and_deadline() {
            service.errorKind = "rate-limit"
            service.now = Date.parse("2026-10-29T09:00:00Z")
            service.retryAt = Date.parse("2026-10-29T09:02:00Z")
            var countdown = findChild(status, "retry-countdown")
            verify(countdown !== null && countdown.visible)
            verify(countdown.text.indexOf("Retry available in 2m") === 0)
            verify(countdown.text.indexOf(new Date(service.retryAt).toLocaleString()) >= 0)
            service.now = Date.parse("2026-10-29T09:01:01Z")
            verify(countdown.text.indexOf("59s") >= 0)
            service.now = service.retryAt
            verify(!countdown.visible)
            verify(findChild(status, "refresh-status").text.indexOf("Refresh") >= 0)
            service.refreshing = true
            service.statusText = "Refreshing GitHub activity…"
            compare(findChild(status, "refresh-status").text, "Refreshing GitHub activity…")
        }
    }
}
