pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Commons as Commons

Column {
    id: root
    required property var service
    readonly property string errorKind: service ? service.errorKind : ""
    readonly property string loginCommand: "gh auth login --hostname github.com"
    readonly property double remainingSeconds: service ? Math.max(0, Math.ceil((service.retryAt - service.now) / 1000)) : 0
    property bool copied: false
    signal actionFocused(Item action)
    spacing: Style.space(6)
    onErrorKindChanged: copied = false
    onVisibleChanged: if (!visible) copied = false

    Text {
        objectName: "refresh-status"
        width: root.width
        text: !root.service ? "Waiting for the shared GitHub service."
            : root.errorKind === "rate-limit" && !root.service.refreshing
                ? root.remainingSeconds > 0 ? "GitHub rate limit reached." : "Rate-limit wait ended. Press Refresh to try again."
                : root.service.statusText
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }

    Text {
        objectName: "retry-countdown"
        width: root.width
        visible: root.errorKind === "rate-limit" && root.remainingSeconds > 0 && !root.service.refreshing
        text: "Retry available in " + (root.remainingSeconds < 60 ? root.remainingSeconds + "s" : Math.ceil(root.remainingSeconds / 60) + "m")
            + (root.service ? " · " + new Date(root.service.retryAt).toLocaleString() : "")
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }

    InfoText {
        id: copyLogin
        objectName: "copy-login-command"
        width: root.width
        visible: root.errorKind === "authentication"
        text: root.copied ? "Login command copied" : "Copy login command"
        tooltipText: root.loginCommand
        link: true
        Accessible.role: Accessible.Button
        onActivated: {
            clipboardSource.selectAll()
            clipboardSource.copy()
            root.copied = true
            copyLogin.Accessible.announce(copyLogin.text, Accessible.Polite)
        }
        onActiveFocusChanged: if (activeFocus) root.actionFocused(copyLogin)
    }

    TextEdit {
        id: clipboardSource
        visible: false
        readOnly: true
        text: root.loginCommand
        Accessible.ignored: true
    }
}
